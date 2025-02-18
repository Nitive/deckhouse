/*
Copyright 2021 Flant CJSC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package hooks

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"

	"github.com/flant/addon-operator/pkg/module_manager/go_hook"
	"github.com/flant/addon-operator/sdk"

	"github.com/deckhouse/deckhouse/dhctl/pkg/template"
)

/*

DESIGN
	- BEFORE HELM {subscribed to MachineDeployments}
		collects checksums of all EXISTING MachineClasses to the map
			nodeManager.internal.machineDeployments:
				"{MachineDeployment name}": "{name, nodeGroup, Checksum}"
		- MachineDeployments in snapshot are always expected to have MachineClass checksum in annotations
		- nodeManager.internal.nodeGroups are always expected to exist

	- HELM in MachineDeployment template, the checksum is set from values
		If the checksum is absent in values, it means the MachineDeployment is being created,
		and the checksum is calculated right in the template.

	- AFTER HELM {} (you are here)
		updates checksums
		- sets checksums in MachineDeployments specs causing nodes to update, if it changes
		- updates checksums in the values

*/

var _ = sdk.RegisterFunc(&go_hook.HookConfig{
	OnAfterHelm: &go_hook.OrderedConfig{Order: 10},
}, assignMachineClassChecksum)

func assignMachineClassChecksum(input *go_hook.HookInput) error {
	checksumTemplate, err := getChecksumTemplate(input.Values)
	if err != nil {
		return err
	}

	ngs, err := parseNodeGroupValues(input.Values)
	if err != nil {
		return fmt.Errorf("cannot parse nodeGroup values: %v", err)
	}

	jsonValues := input.Values.Get(machineDeploymentsInternalValuesPath)
	if !jsonValues.Exists() {
		return nil
	}

	mds := make(map[string]machineDeployment)
	err = json.Unmarshal([]byte(jsonValues.Raw), &mds)
	if err != nil {
		return fmt.Errorf("cannot parse values of machinedeployments: %v", err)
	}

	mdsToUpdate := make([]machineDeployment, 0)
	for _, md := range mds {
		key := fmt.Sprintf("%s.%s", machineDeploymentsInternalValuesPath, md.Name)

		ng := chooseNodeGroupByMachineDeployment(ngs, md)
		if ng == nil {
			// No NodeGroup value for MachineDeployment means we should clean up.
			input.Values.Remove(key)
			continue
		}

		// MachineClass could have changed in helm phase due to manual changes in InstanceClass or NodeGroup.
		// Checksum must be recalculated.
		md.Checksum, err = calcMachineClassChecksum(checksumTemplate, ng)
		if err != nil {
			return fmt.Errorf("cannot calculate checksum for nodeGroup %q and MachineDeployment %q: %v", md.NodeGroup, md.Name, err)
		}

		input.Values.Set(key, md)
		mdsToUpdate = append(mdsToUpdate, md)
	}

	// Update the checksums in machine deployments
	const (
		apiVersion  = "machine.sapcloud.io/v1alpha1"
		kind        = "MachineDeployment"
		namespace   = "d8-cloud-instance-manager"
		subresource = ""
	)

	const machineClassChecksumMergePatchTemplate = `{ "spec": { "template": { "metadata" : { "annotations" : { "checksum/machine-class": %q }}}}}`
	for _, md := range mdsToUpdate {
		patch := []byte(fmt.Sprintf(machineClassChecksumMergePatchTemplate, md.Checksum))
		err := input.ObjectPatcher.MergePatchObject(patch, apiVersion, kind, namespace, md.Name, subresource)
		if err != nil {
			return fmt.Errorf("cannot patch MachineDeployment %q: %v", md.Name, err)
		}
	}

	return nil
}

func calcMachineClassChecksum(checksumTemplate []byte, ng *nodeGroupValue) (string, error) {
	checksum, err := renderMachineClassChecksum(checksumTemplate, ng)
	if err != nil {
		return "", err
	}
	if checksum == "" {
		return "", fmt.Errorf("empty checksum")
	}
	return checksum, nil
}

func renderMachineClassChecksum(templateContent []byte, ng *nodeGroupValue) (string, error) {
	rendered, err := template.RenderTemplate("", templateContent, map[string]interface{}{"nodeGroup": ng.Raw})
	if err != nil {
		return "", err
	}
	checksum := rendered.Content.String()
	return checksum, nil
}

func getChecksumTemplate(values *go_hook.PatchableValues) ([]byte, error) {
	cloudType := values.Get("nodeManager.internal.cloudProvider.type").String()
	if cloudType == "" {
		// Can be empty for the first run even in cloud.
		return nil, fmt.Errorf("cloud type not set")
	}

	path := getChecksumTemplatePath(cloudType)
	content, err := ioutil.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("cannot read checksum template: %v", err)
	}
	return content, err
}

func getChecksumTemplatePath(cloudType string) string {
	modulesDir, ok := os.LookupEnv("MODULES_DIR")
	if !ok {
		modulesDir = "../.."
	}
	path := filepath.Join(modulesDir, "040-node-manager", "cloud-providers", cloudType, "machine-class.checksum")
	return path
}
