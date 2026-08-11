let TestCredential = ../../dhall/test/TestCredential.dhall
let credential = { secretRef = "vault/test/phase54", testSimulation = True } : TestCredential
let _ = assert : credential.testSimulation === True
in credential
