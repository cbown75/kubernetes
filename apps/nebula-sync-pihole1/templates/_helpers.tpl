{{- define "nebula-sync-pihole1.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "nebula-sync-pihole1.labels" -}}
app.kubernetes.io/name: nebula-sync-pihole1
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "nebula-sync-pihole1.selectorLabels" -}}
app.kubernetes.io/name: nebula-sync-pihole1
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
