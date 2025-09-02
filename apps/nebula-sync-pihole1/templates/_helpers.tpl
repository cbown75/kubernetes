{{/*
Expand the name of the chart.
*/}}
{{- define "nebula-sync-pihole1.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "nebula-sync-pihole1.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "nebula-sync-pihole1.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nebula-sync-pihole1.labels" -}}
helm.sh/chart: {{ include "nebula-sync-pihole1.chart" . }}
{{ include "nebula-sync-pihole1.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nebula-sync-pihole1.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nebula-sync-pihole1.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "nebula-sync-pihole1.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "nebula-sync-pihole1.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Validate replica configuration
*/}}
{{- define "nebula-sync-pihole1.validateReplicas" -}}
{{- $urlCount := len .Values.nebulaSync.replicas.urls }}
{{- $keyCount := len .Values.nebulaSync.replicas.passwordSecretKeys }}
{{- if ne $urlCount $keyCount }}
{{- fail (printf "Number of replica URLs (%d) must match number of password secret keys (%d)" $urlCount $keyCount) }}
{{- end }}
{{- end }}
