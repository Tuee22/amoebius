"""Admitted broker names follow the authored headless service topology."""
import contextlib
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
import platform_backbone_live as live


class BrokerHttpTests(unittest.TestCase):
    def test_both_rendered_broker_owners(self):
        for ordinal in (0, 1):
            with self.subTest(ordinal):
                name = "broker-"+str(ordinal)
                response = json.dumps({"brokerUrl": "pulsar://"+name+".broker-headless.pulsar-system.svc.cluster.local:6650"}).encode()
                pod = {"metadata": {"uid": "uid-"+name}, "status": {"containerStatuses": [
                    {"ready": True, "containerID": "container-"+name, "restartCount": 0}]}}
                with patch.object(live, "pulsar_broker_http", return_value=(200,response)), \
                     patch.object(live, "kubectl") as kubectl, patch.object(live, "text", return_value=json.dumps(pod)):
                    actual = live.topic_owner_identity("persistent://phase30/drill/ready-a")
                self.assertEqual(actual, {"pod": name, "uid": "uid-"+name,
                                         "containerID": "container-"+name, "restartCount": 0})
                self.assertEqual(kubectl.call_args.args, ("-n","pulsar-system","get","pod",name,"-o","json"))

    def request(self, location):
        targets, requests = [], []

        @contextlib.contextmanager
        def forward(namespace, target, local, remote):
            targets.append((namespace,target,local,remote))
            yield

        class Response:
            def __init__(self, redirected):
                self.status = 307 if redirected else 204
            def read(self, maximum):
                return b""
            def getheader(self, name):
                return location if self.status == 307 else None

        class Connection:
            def __init__(self, *args, **kwargs):
                self.redirected = not requests
            def request(self, method, path, body, headers):
                requests.append((method,path,body,headers))
            def getresponse(self):
                return Response(self.redirected)
            def close(self):
                pass

        with patch.object(live,"port_forward",forward), patch.object(live.http.client,"HTTPConnection",Connection):
            result = live.pulsar_broker_http("PUT","/admin/v2/persistent/phase30/drill/offload-a",b"{}")
        return result, targets, requests

    def test_rendered_redirect_preserves_put_body(self):
        result, targets, requests = self.request("http://broker-1.broker-headless.pulsar-system.svc.cluster.local:8080/admin/v2/persistent/phase30/drill/offload-a?authoritative=true")
        self.assertEqual(result,(204,b""))
        self.assertEqual([target[1] for target in targets],["service/broker","pod/broker-1"])
        self.assertEqual([(row[0],row[2]) for row in requests],[("PUT",b"{}"),("PUT",b"{}")])
        self.assertEqual(requests[1][1],"/admin/v2/persistent/phase30/drill/offload-a?authoritative=true")

    def test_redirects_outside_actual_topology_or_operation_deny(self):
        base = "http://broker-1.broker-headless.pulsar-system.svc.cluster.local:8080/admin/v2/persistent/phase30/drill/offload-a"
        bad = [base.replace("broker-1.","broker-2."), base.replace("broker-headless","broker"),
               base.replace("broker-headless.pulsar-system.svc.cluster.local","foreign.test"),
               base.replace("http://","https://"), base.replace(":8080",":8081"),
               base.replace("http://","http://attacker@"), base.replace("offload-a","foreign"),
               base+"?foreign=1", base+"?authoritative=true&authoritative=false", base+"#fragment"]
        for url in bad:
            with self.subTest(url), self.assertRaises(live.BackboneLiveFailure):
                self.request(url)


if __name__ == "__main__":
    unittest.main()
