{{/*
Expand the name of the chart.
*/}}
{{- define "travelping-upf-loadtest.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "travelping-upf-loadtest.fullname" -}}
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
{{- define "travelping-upf-loadtest.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "travelping-upf-loadtest.labels" -}}
helm.sh/chart: {{ include "travelping-upf-loadtest.chart" . }}
{{ include "travelping-upf-loadtest.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "travelping-upf-loadtest.selectorLabels" -}}
app.kubernetes.io/name: {{ include "travelping-upf-loadtest.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Legacy component selectors are intentionally stable. Chart 0.1.0 included
these labels in immutable workload selectors, so retaining their original
values permits in-place upgrades while preventing future version churn.
*/}}
{{- define "travelping-upf-loadtest.upf.selectorLabels" -}}
helm.sh/chart: travelping-upf-loadtest-0.1.0
{{ include "travelping-upf-loadtest.selectorLabels" . }}
app.kubernetes.io/version: "1.0.0"
app.kubernetes.io/managed-by: Helm
component: upf
{{- end }}

{{- define "travelping-upf-loadtest.trex.selectorLabels" -}}
helm.sh/chart: travelping-upf-loadtest-0.1.0
{{ include "travelping-upf-loadtest.selectorLabels" . }}
app.kubernetes.io/version: "1.0.0"
app.kubernetes.io/managed-by: Helm
component: trex
{{- end }}

{{- define "travelping-upf-loadtest.pfcp-sim.selectorLabels" -}}
helm.sh/chart: travelping-upf-loadtest-0.1.0
{{ include "travelping-upf-loadtest.selectorLabels" . }}
app.kubernetes.io/version: "1.0.0"
app.kubernetes.io/managed-by: Helm
component: pfcp-sim
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "travelping-upf-loadtest.serviceAccountName" -}}
{{- if .Values.rbac.serviceAccountName }}
{{- .Values.rbac.serviceAccountName }}
{{- else }}
{{- default "default" .Values.serviceAccountName }}
{{- end }}
{{- end }}

{{/*
UPF labels
*/}}
{{- define "travelping-upf-loadtest.upf.labels" -}}
{{- include "travelping-upf-loadtest.labels" . }}
component: upf
{{- end }}

{{/*
TRex labels
*/}}
{{- define "travelping-upf-loadtest.trex.labels" -}}
{{- include "travelping-upf-loadtest.labels" . }}
component: trex
{{- end }}

{{/*
PFCP Sim labels
*/}}
{{- define "travelping-upf-loadtest.pfcp-sim.labels" -}}
{{- include "travelping-upf-loadtest.labels" . }}
component: pfcp-sim
{{- end }}
