{{/*
Expand the name of the chart.
*/}}
{{- define "synology-csi-driver.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "synology-csi-driver.fullname" -}}
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
{{- define "synology-csi-driver.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "synology-csi-driver.labels" -}}
helm.sh/chart: {{ include "synology-csi-driver.chart" . }}
{{ include "synology-csi-driver.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "synology-csi-driver.selectorLabels" -}}
app.kubernetes.io/name: {{ include "synology-csi-driver.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Controller selector labels
*/}}
{{- define "synology-csi-driver.controller.selectorLabels" -}}
{{ include "synology-csi-driver.selectorLabels" . }}
app.kubernetes.io/component: controller
{{- end }}

{{/*
Node selector labels
*/}}
{{- define "synology-csi-driver.node.selectorLabels" -}}
{{ include "synology-csi-driver.selectorLabels" . }}
app.kubernetes.io/component: node
{{- end }}

{{/*
Controller service account name
*/}}
{{- define "synology-csi-driver.controller.serviceAccountName" -}}
{{- printf "%s-controller-sa" (include "synology-csi-driver.fullname" .) }}
{{- end }}

{{/*
Node service account name
*/}}
{{- define "synology-csi-driver.node.serviceAccountName" -}}
{{- printf "%s-node-sa" (include "synology-csi-driver.fullname" .) }}
{{- end }}
