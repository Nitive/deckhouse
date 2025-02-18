/*
Copyright 2021 Flant CJSC
Licensed under the Deckhouse Platform Enterprise Edition (EE) license. See https://github.com/deckhouse/deckhouse/ee/LICENSE
*/

package hooks

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "github.com/deckhouse/deckhouse/testing/hooks"
)

var _ = Describe("Modules :: secret-copier :: hooks :: handler ::", func() {
	const (
		stateNamespaces = `
---
apiVersion: v1
kind: Namespace
metadata:
  name: default
---
apiVersion: v1
kind: Namespace
metadata:
  name: ns1
---
apiVersion: v1
kind: Namespace
metadata:
  name: ns2
---
apiVersion: v1
kind: Namespace
metadata:
  name: ns3t
status:
  phase: Terminating
---
apiVersion: v1
kind: Namespace
metadata:
  name: ns4u
  labels:
    heritage: upmeter
`
		stateSecretsNeutral = `
---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: neutral
  namespace: default
data:
  supersecret: YWJj
`

		stateSecretsOriginal = `
---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: s1
  namespace: default
  labels:
    secret-copier.deckhouse.io/enabled: ""
    certmanager.k8s.io/certificate-name: certname
data:
  supersecret: czFkYXRh
---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: s2
  namespace: default
  labels:
    secret-copier.deckhouse.io/enabled: ""
data:
  supersecret: czJkYXRh
---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: s3
  namespace: default
  labels:
    secret-copier.deckhouse.io/enabled: ""
data:
  supersecret: czNkYXRh
`
		stateSecretsExtra = `
---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: es1
  namespace: ns1
  labels:
    secret-copier.deckhouse.io/enabled: ""
data:
  supersecret: ZXMxZGF0YQ==
---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: es2
  namespace: ns2
  labels:
    secret-copier.deckhouse.io/enabled: ""
data:
  supersecret: ZXMyZGF0YQ==
`
		stateSecretsUpToDate = `
---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: s1
  namespace: ns1
  labels:
    secret-copier.deckhouse.io/enabled: ""
data:
  supersecret: czFkYXRh
`
		stateSecretsOutDated = `
---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: s2
  namespace: ns1
  labels:
    secret-copier.deckhouse.io/enabled: ""
data:
  supersecret: b2xkX3MyX2RhdGE=
`
	)

	f := HookExecutionConfigInit(`{}`, `{}`)

	Context("Empty cluster", func() {
		BeforeEach(func() {
			f.BindingContexts.Set(f.KubeStateSet(``))
			f.RunHook()
		})

		It("Hook must not fail", func() {
			Expect(f).To(ExecuteSuccessfully())
		})
	})

	Context("Namespaces and all types of secrets are in cluster", func() {
		BeforeEach(func() {
			f.BindingContexts.Set(f.KubeStateSet(stateNamespaces + stateSecretsOriginal + stateSecretsNeutral + stateSecretsExtra + stateSecretsOutDated + stateSecretsUpToDate))
			f.RunHook()
		})

		It("Six secrets must be actual", func() {
			Expect(f).To(ExecuteSuccessfully())

			Expect(f.KubernetesResource("Secret", "ns1", "es1").Exists()).To(BeFalse())
			Expect(f.KubernetesResource("Secret", "ns2", "es2").Exists()).To(BeFalse())

			Expect(f.KubernetesResource("Secret", "ns1", "s1").Exists()).To(BeTrue())
			Expect(f.KubernetesResource("Secret", "ns1", "s2").Exists()).To(BeTrue())
			Expect(f.KubernetesResource("Secret", "ns1", "s3").Exists()).To(BeTrue())
			Expect(f.KubernetesResource("Secret", "ns2", "s1").Exists()).To(BeTrue())
			Expect(f.KubernetesResource("Secret", "ns2", "s2").Exists()).To(BeTrue())
			Expect(f.KubernetesResource("Secret", "ns2", "s3").Exists()).To(BeTrue())
			Expect(f.KubernetesResource("Secret", "ns3t", "s1").Exists()).To(BeFalse())
			Expect(f.KubernetesResource("Secret", "ns3t", "s2").Exists()).To(BeFalse())
			Expect(f.KubernetesResource("Secret", "ns3t", "s3").Exists()).To(BeFalse())
			Expect(f.KubernetesResource("Secret", "ns4u", "s1").Exists()).To(BeFalse())
			Expect(f.KubernetesResource("Secret", "ns4u", "s2").Exists()).To(BeFalse())
			Expect(f.KubernetesResource("Secret", "ns4u", "s3").Exists()).To(BeFalse())

			Expect(f.KubernetesResource("Secret", "ns1", "s1").Field("data.supersecret").String()).To(Equal("czFkYXRh"))
			Expect(f.KubernetesResource("Secret", "ns1", "s2").Field("data.supersecret").String()).To(Equal("czJkYXRh"))
			Expect(f.KubernetesResource("Secret", "ns1", "s3").Field("data.supersecret").String()).To(Equal("czNkYXRh"))
			Expect(f.KubernetesResource("Secret", "ns2", "s1").Field("data.supersecret").String()).To(Equal("czFkYXRh"))
			Expect(f.KubernetesResource("Secret", "ns2", "s2").Field("data.supersecret").String()).To(Equal("czJkYXRh"))
			Expect(f.KubernetesResource("Secret", "ns2", "s3").Field("data.supersecret").String()).To(Equal("czNkYXRh"))

			Expect(f.KubernetesResource("Secret", "ns1", "s1").Field("metadata.labels").Map()).ToNot(HaveKey("certmanager.k8s.io/certificate-name"))
			Expect(f.KubernetesResource("Secret", "ns2", "s1").Field("metadata.labels").Map()).ToNot(HaveKey("certmanager.k8s.io/certificate-name"))
		})
	})

	Context("Namespaces and all types of secrets are in cluster", func() {
		BeforeEach(func() {
			f.KubeStateSet(stateNamespaces + stateSecretsOriginal + stateSecretsNeutral + stateSecretsExtra + stateSecretsOutDated + stateSecretsUpToDate)
			f.BindingContexts.Set(f.GenerateScheduleContext("0 3 * * *"))
			f.RunHook()
		})

		It("Six secrets must be actual", func() {
			Expect(f).To(ExecuteSuccessfully())

			Expect(f.KubernetesResource("Secret", "ns1", "es1").Exists()).To(BeFalse())
			Expect(f.KubernetesResource("Secret", "ns2", "es2").Exists()).To(BeFalse())

			Expect(f.KubernetesResource("Secret", "ns1", "s1").Exists()).To(BeTrue())
			Expect(f.KubernetesResource("Secret", "ns1", "s2").Exists()).To(BeTrue())
			Expect(f.KubernetesResource("Secret", "ns1", "s3").Exists()).To(BeTrue())
			Expect(f.KubernetesResource("Secret", "ns2", "s1").Exists()).To(BeTrue())
			Expect(f.KubernetesResource("Secret", "ns2", "s2").Exists()).To(BeTrue())
			Expect(f.KubernetesResource("Secret", "ns2", "s3").Exists()).To(BeTrue())
			Expect(f.KubernetesResource("Secret", "ns3t", "s1").Exists()).To(BeFalse())
			Expect(f.KubernetesResource("Secret", "ns3t", "s2").Exists()).To(BeFalse())
			Expect(f.KubernetesResource("Secret", "ns3t", "s3").Exists()).To(BeFalse())
			Expect(f.KubernetesResource("Secret", "ns4u", "s1").Exists()).To(BeFalse())
			Expect(f.KubernetesResource("Secret", "ns4u", "s2").Exists()).To(BeFalse())
			Expect(f.KubernetesResource("Secret", "ns4u", "s3").Exists()).To(BeFalse())

			Expect(f.KubernetesResource("Secret", "ns1", "s1").Field("data.supersecret").String()).To(Equal("czFkYXRh"))
			Expect(f.KubernetesResource("Secret", "ns1", "s2").Field("data.supersecret").String()).To(Equal("czJkYXRh"))
			Expect(f.KubernetesResource("Secret", "ns1", "s3").Field("data.supersecret").String()).To(Equal("czNkYXRh"))
			Expect(f.KubernetesResource("Secret", "ns2", "s1").Field("data.supersecret").String()).To(Equal("czFkYXRh"))
			Expect(f.KubernetesResource("Secret", "ns2", "s2").Field("data.supersecret").String()).To(Equal("czJkYXRh"))
			Expect(f.KubernetesResource("Secret", "ns2", "s3").Field("data.supersecret").String()).To(Equal("czNkYXRh"))
		})
	})
})
