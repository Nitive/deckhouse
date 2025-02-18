/*
Copyright 2021 Flant CJSC
Licensed under the Deckhouse Platform Enterprise Edition (EE) license. See https://github.com/deckhouse/deckhouse/ee/LICENSE
*/

package hooks

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"strings"

	"github.com/flant/addon-operator/pkg/module_manager/go_hook"
	"github.com/flant/addon-operator/sdk"
	"github.com/google/go-containerregistry/pkg/authn"
	log "github.com/sirupsen/logrus"
)

var _ = sdk.RegisterFunc(&go_hook.HookConfig{
	OnBeforeHelm: &go_hook.OrderedConfig{Order: 1},
}, handle)

// This hook discovers license key from values or docker config, and puts it into internal values to use elsewhere.
func handle(input *go_hook.HookInput) error {
	const internalLicenseKeyPath = "flantIntegration.internal.licenseKey"

	// From config values
	configLicenseKey := input.ConfigValues.Get("flantIntegration.licenseKey").String()
	if configLicenseKey != "" {
		input.Values.Set(internalLicenseKeyPath, configLicenseKey)
		return nil
	}

	// From docker registry config, where license key is the password to access container registry
	registry := input.Values.Get("global.modulesImages.registry").String()
	const dockerConfigPath = "/etc/registrysecret/.dockerconfigjson"
	licenseKey, err := getLicenseKeyFromDockerConfig(registry, dockerConfigPath)
	if err != nil {
		return err
	}
	input.Values.Set(internalLicenseKeyPath, licenseKey)

	return nil
}

func getLicenseKeyFromDockerConfig(registryValue, dockerConfigPath string) (string, error) {
	registryHost, err := parseRegistryHost(registryValue)
	if err != nil {
		return "", fmt.Errorf("empty registry: %v", err)
	}

	cfg, err := ioutil.ReadFile(dockerConfigPath)
	if err != nil {
		log.Warnf("cannot open %q: %v", dockerConfigPath, err)
		return "", fmt.Errorf(`cannot find license key in docker config file; set "flantIntegration.licenseKey" in deckhouse configmap`)
	}

	return parseLicenseKeyFromDockerCredentials(cfg, registryHost)
}

func parseRegistryHost(repo string) (string, error) {
	if repo == "" {
		return "", fmt.Errorf("repo is empty")
	}
	repoSegments := strings.Split(repo, "/")
	if len(repoSegments) == 0 {
		return "", fmt.Errorf("repo is empty")
	}
	registry := repoSegments[0]
	return registry, nil
}

func parseLicenseKeyFromDockerCredentials(dockerConfig []byte, registry string) (string, error) {
	var auth dockerFileConfig
	err := json.Unmarshal(dockerConfig, &auth)
	if err != nil {
		return "", fmt.Errorf("cannot decode docker config JSON: %v", err)
	}
	creds, ok := auth.Auths[registry]
	if !ok {
		return "", fmt.Errorf("no credentials for current registry")
	}

	if creds.Password != "" {
		return creds.Password, nil
	}

	if creds.Auth != "" {
		auth, err := base64.StdEncoding.DecodeString(creds.Auth)
		if err != nil {
			return "", fmt.Errorf(`cannot decode base64 "auth" field`)
		}
		parts := strings.Split(string(auth), ":")
		if len(parts) != 2 {
			return "", fmt.Errorf(`unexpected format of "auth" field`)
		}
		return parts[1], nil
	}

	return "", fmt.Errorf("licenseKey not set in dockerconfig")
}

/*
	{ "auths":{
	        "registry.example.com":{
			"username":"oauth2",
			"password":"...",
			"auth":"...",
			"email":"...@example.com"
		}
	}}
*/
type dockerFileConfig struct {
	Auths map[string]authn.AuthConfig `json:"auths"`
}
