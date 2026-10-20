# These are Go typed selectors, never raw Engine JSON selectors. No emulator.
$script:Projection=@{
 owner='{"id":{{json .ID}},"name":{{json .Name}},"image":{{json .Image}},"run":{{json (index .Config.Labels "com.wed-snap.run")}},"task":{{json (index .Config.Labels "com.wed-snap.task")}}}'
 state='{"id":{{json .ID}},"running":{{json .State.Running}},"status":{{json .State.Status}},"exit":{{json .State.ExitCode}},"oom":{{json .State.OOMKilled}},"errorPresent":{{if .State.Error}}true{{else}}false{{end}}}'
 guard='{"id":{{json .ID}},"user":{{json .Config.User}},"rootRO":{{json .HostConfig.ReadonlyRootfs}},"privileged":{{json .HostConfig.Privileged}},"capAdd":{{json .HostConfig.CapAdd}},"capDrop":{{json .HostConfig.CapDrop}},"security":{{json .HostConfig.SecurityOpt}},"memory":{{json .HostConfig.Memory}},"swap":{{json .HostConfig.MemorySwap}},"pids":{{json .HostConfig.PidsLimit}},"nanoCPU":{{json .HostConfig.NanoCPUs}},"ipc":{{json .HostConfig.IpcMode}},"cgroupns":{{json .HostConfig.CgroupnsMode}},"network":{{json .HostConfig.NetworkMode}},"portCount":{{len .HostConfig.PortBindings}},"networks":[{{$first := true}}{{range $name,$endpoint := .NetworkSettings.Networks}}{{if $first}}{{$first = false}}{{else}},{{end}}{{json $name}}{{end}}],"tmpfs":{{json .HostConfig.Tmpfs}},"mounts":[{{range $i,$m := .Mounts}}{{if $i}},{{end}}{"type":{{json $m.Type}},"target":{{json $m.Destination}},"rw":{{json $m.RW}}}{{end}}]}'
 mountTypes='{"id":{{json .ID}},"types":[{{range $i,$m := .Mounts}}{{if $i}},{{end}}{{json $m.Type}}{{end}}]}'
 image='{"id":{{json .ID}},"volumes":{{json .Config.Volumes}}}'
 list='{{.ID}}'
}
# Network map keys are strings; a boolean handles commas without emitting values.
$script:FieldInventory=@{
 '.ID'='InspectResponse.ID string; JSON Id (also image InspectResponse and ps formatter ID)'
 '.Name'='InspectResponse.Name string'
 '.Image'='InspectResponse.Image string'
 '.Config.Labels'='Config* -> Labels map[string]string; index missing label returns empty, rejected'
 '.Config.User'='Config* -> User string'
 '.State.Running'='State* -> Running bool'
 '.State.Status'='State* -> Status ContainerState string'
 '.State.ExitCode'='State* -> ExitCode int'
 '.State.OOMKilled'='State* -> OOMKilled bool'
 '.State.Error'='State* -> Error string; projected as bool only'
 '.HostConfig.ReadonlyRootfs'='HostConfig* -> ReadonlyRootfs bool'
 '.HostConfig.Privileged'='HostConfig* -> Privileged bool'
 '.HostConfig.CapAdd'='HostConfig* -> CapAdd []string; nil allowed as no additions'
 '.HostConfig.CapDrop'='HostConfig* -> CapDrop []string; nil rejected'
 '.HostConfig.SecurityOpt'='HostConfig* -> SecurityOpt []string; nil rejected'
 '.HostConfig.Memory'='HostConfig* embeds Resources.Memory int64'
 '.HostConfig.MemorySwap'='HostConfig* embeds Resources.MemorySwap int64'
 '.HostConfig.PidsLimit'='HostConfig* embeds Resources.PidsLimit *int64; nil rejected'
 '.HostConfig.NanoCPUs'='HostConfig* embeds Resources.NanoCPUs int64; JSON NanoCpus'
 '.HostConfig.IpcMode'='HostConfig* -> IpcMode string alias'
 '.HostConfig.CgroupnsMode'='HostConfig* -> CgroupnsMode string alias'
 '.HostConfig.NetworkMode'='HostConfig* -> NetworkMode string alias'
 '.HostConfig.PortBindings'='HostConfig* -> network.PortMap map[Port][]PortBinding; len nil=0'
 '.HostConfig.Tmpfs'='HostConfig* -> map[string]string; nil rejected for planned tmpfs'
 '.NetworkSettings.Networks'='NetworkSettings* -> map[string]*EndpointSettings; only keys emitted, nil rejected by expected none'
 '.Mounts'='InspectResponse.Mounts []MountPoint; nil range empty, missing planned mounts rejected'
 '$m.Type'='MountPoint.Type mount.Type string alias; nil/unknown rejected'
 '$m.Destination'='MountPoint.Destination string'
 '$m.RW'='MountPoint.RW bool'
 '.Config.Volumes'='image Config* -> embedded DockerOCIImageConfig.Volumes map[string]struct{}; null means no declared volumes'
}
function Assert-ProjectionContracts($Templates=$script:Projection){
 if($Templates.Count -ne 6){throw 'TEMPLATE_CONTRACT'}
 foreach($k in $script:Projection.Keys){if(!$Templates.ContainsKey($k) -or $Templates[$k] -cne $script:Projection[$k]){throw 'TEMPLATE_CONTRACT'}}
 # Static selector inventory, not Go template parsing/execution.
 $seen=@{}
 foreach($t in $Templates.Values){foreach($m in [regex]::Matches($t,'(?<![\w$])\.(?:[A-Z][A-Za-z0-9]*)(?:\.[A-Z][A-Za-z0-9]*)*|\$m\.(?:Type|Destination|RW)')){
  $key=$m.Value;if(!$script:FieldInventory.ContainsKey($key)){throw 'UNINVENTORIED_TYPED_FIELD'};$seen[$key]=$true
 }}
 if($seen.Count -ne $script:FieldInventory.Count){throw 'UNUSED_FIELD_CONTRACT'}
}
