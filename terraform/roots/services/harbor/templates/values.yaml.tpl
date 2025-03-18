expose:
  type: ingress
  ingress:
    hosts:
      core: "harbor.{{ regex_replace(var.external_url, \"https?://\", \"\") }}"
    annotations: {}
    tls: []

externalURL: "{{ external_url }}"

{{- if var.admin_secret_name != "" }}
existingSecretAdminPassword: "{{ admin_secret_name }}"
existingSecretAdminPasswordKey: "HARBOR_ADMIN_PASSWORD"
harborAdminPassword: "unused"
{{- else }}
harborAdminPassword: "dummy"
{{- end }}

persistence:
  imageChartStorage:
    disableredirect: true
    {{- if var.use_s3_storage }}
    type: "s3"
    s3:
      bucket: "{{ s3_bucket }}"
      region: "{{ s3_region }}"
      regionendpoint: "{{ s3_endpoint }}"
      secure: {{ s3_secure }}
      {{- if var.s3_secret_name != "" }}
      existingSecret: "{{ s3_secret_name }}"
      {{- else }}
      accesskey: "dummy-s3-access"
      secretkey: "dummy-s3-secret"
      {{- end }}
    {{- else }}
    type: "filesystem"
    filesystem:
      rootdirectory: "/data"
    {{- end }}

{{- if var.vault_injection }}
registry:
  podAnnotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/agent-inject-secret-minio: "{{ vault_minio_path }}"
    vault.hashicorp.com/agent-inject-template-minio: |-
      {{`{{- with secret \"`}}{{ vault_minio_path }}{{`\" -}}`}}
      [default]
      aws_access_key_id={{`{{ .Data.data.access_key }}`}}
      aws_secret_access_key={{`{{ .Data.data.secret_key }}`}}
      {{`{{- end }}`}}
    vault.hashicorp.com/agent-inject-file-mode-minio: "0440"
    vault.hashicorp.com/agent-pre-populate: "true"

core:
  podAnnotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/agent-inject-secret-dockerhub: "{{ vault_dockerhub_path }}"
{{- end }}
