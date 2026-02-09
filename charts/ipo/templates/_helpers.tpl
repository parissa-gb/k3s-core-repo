{{/* Generate chart base name */}}
{{- define "ipo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Generate fully qualified chart name */}}
{{- define "ipo.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name  | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "ipo.namespace" -}}
{{- if .Values.namespaceOverride }}
{{- .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- else }}
{{- .Release.Namespace | trunc 63 | trimSuffix "-" -}}
{{- end }}
{{- end -}}

{{/* Generate chart name with release name */}}
{{- define "ipo.fullnameOverride" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else }}
{{- include "ipo.name" . | trunc 63 | trimSuffix "-" -}}
{{- end }}
{{- end -}}

{{/* Generate chart name with release name */}}
{{- define "ipo.releaseName" -}}
{{- printf "%s-%s" (include "ipo.fullname" .) .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Common labels */}}
{{- define "ipo.labels" -}}
helm.sh/chart: "{{ include "ipo.name" . }}-{{ .Chart.Version }}"
app.kubernetes.io/name: "{{ include "ipo.name" . }}"
app.kubernetes.io/instance: "{{ .Release.Name }}"
app.kubernetes.io/version: "{{ .Chart.AppVersion }}"
app.kubernetes.io/managed-by: "Helm"
{{- end -}}

{{/* Selector labels that match the DaemonSet pods */}}
{{- define "ipo.selectorLabels" -}}
app.kubernetes.io/instance: "{{ include "ipo.fullname" . }}"
{{- end -}}

{{/* Helper for node/pod/podAnti affinities */}}
{{- define "ipo.affinity" -}}
{{- if or .Values.affinity.node .Values.affinity.pod .Values.affinity.podAnti }}
affinity:
  {{- if .Values.affinity.node }}
  nodeAffinity:
    {{- toYaml .Values.affinity.node | nindent 3}}
  {{- end }}
  {{- if .Values.affinity.pod }}
  podAffinity:
    {{- toYaml .Values.affinity.pod | nindent 3 }}
  {{- end }}
  {{- if .Values.affinity.podAnti }}
  podAntiAffinity:
    {{- toYaml .Values.affinity.podAnti | nindent 3 }}
  {{- end }}
{{- else }}
# No affinity rules defined
{{- end }}
{{- end -}}

{{/*  Define the image to use */}}
{{- define "ipo.image" -}}
{{- if and .Values.image.repository .Values.image.tag .Values.image.digest -}}
{{- printf "%s:%s@%s" .Values.image.repository .Values.image.tag .Values.image.digest -}}
{{- else if and .Values.image.repository .Values.image.digest -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- else if and .Values.image.repository .Values.image.tag -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}
{{- end -}}

{{/* Define Storage volume */}}
{{- define "ipo.volume" -}}
{{- range .Values.storageConfigs }}
- name: {{ .name | quote }}
{{- if eq .type "hostPath" }}
  hostPath:
    path: {{ .path | quote }}
  {{- end }}
  {{- if eq .type "configMap" }}
  configMap:
    name: {{ include "ipo.fullname" $ }}-config
    items:
    {{- range .items }}
      - key: {{ .key | quote }}
        path: {{ .path | quote }}
    {{- end }}
  {{- end }}
  {{/* define additional volume types here */}}
{{- end }}
{{- end }}

{{/* Get the Nth key in the first configMap in Configs, or nothing if not found */}}
{{- define "ipo.nthConfigMapKey" -}}
{{- $n := (int (default 0 .n)) -}}
{{- $found := dict }}
{{- range .Values.storageConfigs }}
  {{- if and (eq .type "configMap") (not $found.items) }}
    {{- $_ := set $found "items" .items }}
  {{- end }}
{{- end }}
{{- if and $found.items (gt (len $found.items) $n) -}}
  {{- (index $found.items $n).key | quote -}}
{{- end -}}
{{- end -}}

{{/* Convert a decimal number to hexadecimal */}}
{{- define "ipo.decimalToHex" -}}
{{- printf "0x%02X" (int .) -}}  
{{- end -}}

{{/* Format a float to one decimal place */}}
{{- define "ipo.formatFloat" -}}
{{- printf "%.1f" . -}}
{{- end -}}

{{/* Convert a decimal number to 2-digit decimal string */}}
{{- define "ipo.decimalTo2Digit" -}}
{{- printf "%02d" (int .) -}}
{{- end -}}

{{/* Check if a key exists and is not nil in a given object */}}
{{- define "exists" -}}
{{- if and (hasKey (index . 0) (index . 1)) (ne (index (index . 0) (index . 1)) nil) }}1{{- end -}}
{{- end -}}

{{/* Generate assetID prefix based on chart name, passed component name and a passed hex suffix */}}
{{- define "ipo.assetID" -}}
{{- $root := index . 0 -}}
{{- $componentName := index . 1 -}}
{{- $suffixDec := index . 2 -}}
{{- $chartName := include "ipo.name" $root -}}
{{- $suffix := (include "ipo.decimalTo2Digit" $suffixDec) -}}
{{- $customer := required "values.customer is required to build asset_id" $root.Values.customer -}}
{{- printf "GB-%s-%s-%s-%s" $chartName $root.Values.customer $componentName $suffix | upper -}}
{{- end -}}


{{/* Create bowl_dispenser block */}}
{{/* Its placement differs in compact and compact-box */}}
{{- define "ipo.bowlDispenser" -}}
{{- $configmap := $.Values.configmap }}
{{- range $bowlDispenser, $dispenser := $configmap.ipo.bowl_dispensers }}
{{- if $dispenser.enabled }}
{{ $bowlDispenser }}:
  display_name: {{ $dispenser.display_name | quote }}
  device_type: {{ $dispenser.device_type | quote }}
  {{- if include "exists" (list $dispenser "asset_id") }}
  asset_id: {{ $dispenser.asset_id | quote }}
  {{- else }}
  {{- $numStr := regexReplaceAll "^bowl_dispenser_([0-9]+)$" $bowlDispenser "$1" -}}
  {{- $num := int $numStr }}
  asset_id: {{ include "ipo.assetID" (list $ "bowl-dispenser" $num) | quote }}
  {{- end }}
  component_name: {{ $dispenser.component_name | quote }}
  interface_type: {{ $dispenser.interface_type | default $.Values.configmap.bowl_dispenser_interface | quote -}}
  {{/* Specific for no compact-box */}}
  {{- if (not (eq  $.Values.systemType "compact-box")) }}
  {{- if and (hasKey $dispenser "has_bowl_gripper") (ne $dispenser.has_bowl_gripper nil) }}
  has_bowl_gripper: {{ $dispenser.has_bowl_gripper }}
  {{- end }}
  {{- if and (hasKey $dispenser "has_conveyor") (ne $dispenser.has_conveyor nil) }}
  has_conveyor: {{ $dispenser.has_conveyor }}
  {{- if and (hasKey $dispenser "state_machine") (ne $dispenser.state_machine nil) }}
  state_machine:
    {{- if include "exists" (list $dispenser.state_machine "wait_for_refill_when_empty") }}
    wait_for_refill_when_empty: {{ $dispenser.state_machine.wait_for_refill_when_empty }}
    {{- end }}
    {{- if include "exists" (list $dispenser.state_machine "bowl_buffer_count") }}
    bowl_buffer_count: {{ $dispenser.state_machine.bowl_buffer_count }}
    {{- end }}
    {{- if include "exists" (list $dispenser.state_machine "bowl_type_dispensed") }}
    bowl_type_dispensed: {{ $dispenser.state_machine.bowl_type_dispensed | quote }}
    {{- end }}
    {{- if include "exists" (list $dispenser.state_machine "refill_debounce_count") }}
    refill_debounce_count: {{ $dispenser.state_machine.refill_debounce_count }}
    {{- end }}
    {{- if include "exists" (list $dispenser.state_machine "refill_debounce_interval") }}
    refill_debounce_interval: {{ printf "%.1f" $dispenser.state_machine.refill_debounce_interval }}
    {{- end }}
    {{- if include "exists" (list $dispenser.state_machine "denesting_timeout") }}
    denesting_timeout: {{ printf "%.1f" $dispenser.state_machine.denesting_timeout }}
    {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
  bowl_type_dispensed: {{ $dispenser.bowl_type_dispensed | quote -}}
  {{/* Specifically for compact-box */}}
  {{- if eq  $.Values.systemType "compact-box" }}
  {{- if and (hasKey $dispenser "can_node_id") (ne $dispenser.can_node_id nil) }}
  can_node_id: {{ $dispenser.can_node_id }}
  {{- end }}
  {{- if and (hasKey $dispenser "dispensing_state_machine") (ne $dispenser.dispensing_state_machine nil) }}
  dispensing_state_machine:
    gripper_pickup_debounce_interval_sec: {{ $dispenser.dispensing_state_machine.gripper_pickup_debounce_interval_sec }}
    gripper_pickup_debounce_count: {{ $dispenser.dispensing_state_machine.gripper_pickup_debounce_count }}
    gripper_return_debounce_interval_sec: {{ $dispenser.dispensing_state_machine.gripper_return_debounce_interval_sec }}
    gripper_return_debounce_count: {{ $dispenser.dispensing_state_machine.gripper_return_debounce_count }}
  {{- end }}
  {{- end }}

  {{- if  $dispenser.denester.enabled }}
  {{- if include "exists" (list $dispenser "denester") }}
  denester:
    can_node_id: {{ $dispenser.denester.can_node_id }}
    target_speed: {{ printf "%.1f" $dispenser.denester.target_speed }}
    {{- if include "exists" (list $dispenser.denester "bowl_type_dispensed") }}
    bowl_type_dispensed: {{ $dispenser.denester.bowl_type_dispensed | quote }}
    {{- end }}
    {{- if include "exists" (list $dispenser.denester "bowl_level_sensor") }}
    bowl_level_sensor:
      parameter_index_name: {{ $dispenser.denester.bowl_level_sensor.parameter_index_name | quote }}
      sensor_name: {{ $dispenser.denester.bowl_level_sensor.sensor_name | quote }}
    {{- end }}
    {{- if include "exists" (list $dispenser.denester "end_stop") }}
    end_stop:
      {{- if include "exists" (list $dispenser.denester.end_stop "sensor_name") }}
      sensor_name: {{ $dispenser.denester.end_stop.sensor_name | quote }}
      {{- end }}
      {{- if include "exists" (list $dispenser.denester.end_stop "parameter_index_name") }}
      parameter_index_name: {{ $dispenser.denester.end_stop.parameter_index_name | quote }}
      {{- end }}
      {{- if include "exists" (list $dispenser.denester.end_stop "stop_delay") }}
      stop_delay: {{ printf "%.1f" $dispenser.denester.end_stop.stop_delay }}
      {{- end }}
      {{- if include "exists" (list $dispenser.denester.end_stop "trigger_edge_type") }}
      trigger_edge_type: {{ $dispenser.denester.end_stop.trigger_edge_type | quote }}
      {{- end }}
      {{- if include "exists" (list $dispenser.denester.end_stop "edge_type") }}
      edge_type: {{ $dispenser.denester.end_stop.edge_type | quote }}
      {{- end }}
      {{- if include "exists" (list $dispenser.denester.end_stop "inverted") }}
      inverted: {{ $dispenser.denester.end_stop.inverted }}
      {{- end }}
    {{- end }}
    {{- end }}
    {{- if include "exists" (list $dispenser.denester "stepper") }}
    stepper:
      {{- if include "exists" (list $dispenser.denester.stepper "invert_direction") }}
      invert_direction: {{ $dispenser.denester.stepper.invert_direction }}
      {{- end }}
      {{- if include "exists" (list $dispenser.denester.stepper "micro_steps") }}
      micro_steps: {{ $dispenser.denester.stepper.micro_steps }}
      {{- end }}
      {{- if include "exists" (list $dispenser.denester.stepper "gear_ratio") }}
      gear_ratio: {{ $dispenser.denester.stepper.gear_ratio }}
      {{- end }}
      {{- if include "exists" (list $dispenser.denester.stepper "motor_current") }}
      motor_current: {{ $dispenser.denester.stepper.motor_current }}
      {{- end }}
      {{- if include "exists" (list $dispenser.denester.stepper "max_acceleration") }}
      max_acceleration: {{ $dispenser.denester.stepper.max_acceleration }}
      {{- end }}
      {{- if include "exists" (list $dispenser.denester.stepper "max_speed") }}
      max_speed: {{ $dispenser.denester.stepper.max_speed }}
      {{- end }}
    {{- end }}
  {{- end }}


  {{- if include "exists" (list $dispenser "conveyor") }}
  {{- if $dispenser.conveyor.enabled }}
  conveyor:
    {{- if include "exists" (list $dispenser.conveyor "can_node_id") }}
    can_node_id: {{ $dispenser.conveyor.can_node_id }}
    {{- end }}
    {{-  if include "exists" (list $dispenser.conveyor "end_stop") }}
    end_stop:
      {{- if include "exists" (list $dispenser.conveyor.end_stop "parameter_index_name") }}
      parameter_index_name: {{ $dispenser.conveyor.end_stop.parameter_index_name | quote }}
      {{- end }}
      {{- if include "exists" (list $dispenser.conveyor.end_stop "stop_delay") }}
      stop_delay: {{ printf "%.1f" $dispenser.conveyor.end_stop.stop_delay }}
      {{- end }}
      {{- if include "exists" (list $dispenser.conveyor.end_stop "edge_type") }}
      edge_type: {{ $dispenser.conveyor.end_stop.edge_type | quote }}
      {{- end }}
    {{- end }}
    {{- if include "exists" (list $dispenser.conveyor "bowl_gripper_sensor") }}
    bowl_gripper_sensor: 
      {{- if include "exists" (list $dispenser.conveyor.bowl_gripper_sensor "parameter_index_name") }}
      parameter_index_name: {{ $dispenser.conveyor.bowl_gripper_sensor.parameter_index_name | quote }}
      {{- end }}
      {{- if include "exists" (list $dispenser.conveyor.bowl_gripper_sensor "sensor_name") }}
      sensor_name: {{ $dispenser.conveyor.bowl_gripper_sensor.sensor_name | quote }}
      {{- end }}
    {{- end }}
    {{- if include "exists" (list $dispenser.conveyor "motor_direction") }}
    motor_direction: {{ $dispenser.conveyor.motor_direction }}
    {{- end }}
  {{- end }}
  {{- end }}

  
    
    
{{- end }}
{{- end }}
{{- end -}}



