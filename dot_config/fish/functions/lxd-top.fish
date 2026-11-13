function lxd-top --description 'LXD/MicroCloud cluster usage: per-member CPU/mem/disk allocation + Ceph capacity, pools and buckets'
    set -l remote $argv[1]
    if test -z "$remote"
        set remote microcloud
    end

    # List cluster members. Every lxc/ssh call is guarded by a perl alarm so an
    # unreachable remote (lxc retries with backoff and can block for ages)
    # cannot hang the command.
    set -l members (perl -e 'alarm shift; exec @ARGV' 20 lxc cluster list "$remote:" -f csv < /dev/null 2>/dev/null | cut -d, -f1)
    if test -z "$members"
        echo "error: no response from remote '$remote' within 20s" >&2
        return 1
    end

    # All instances across all projects, once (allocations are summed per member)
    set -l all (perl -e 'alarm shift; exec @ARGV' 30 lxc query "$remote:/1.0/instances?all-projects=true&recursion=1" < /dev/null 2>/dev/null)

    # Storage pools: the first local (non-Ceph) pool is used for per-member disk
    # usage; Ceph-backed pools are cluster-wide and reported separately below.
    set -l pools_json (perl -e 'alarm shift; exec @ARGV' 15 lxc query "$remote:/1.0/storage-pools?recursion=1" < /dev/null 2>/dev/null | string collect)
    set -l pool (printf '%s' $pools_json | jq -r '[.[] | select(.driver | startswith("ceph") | not) | .name][0] // empty' 2>/dev/null)
    set -l ceph_pools (printf '%s' $pools_json | jq -r '.[] | select(.driver | startswith("ceph")) | .name' 2>/dev/null)
    if test -z "$pools_json"
        set pool default
    end

    for n in $members
        printf '== %s ==\n' $n

        set -l res
        set -l threads
        set -l mem_bytes
        set -l mem_total
        set -l alloc
        set -l cpu_alloc
        set -l mem_alloc
        set -l cpu_pct
        set -l mem_pct
        set -l disk_alloc
        set -l disk
        set -l line

        # Host capacity (threads + total memory) from the resources API
        set res (perl -e 'alarm shift; exec @ARGV' 15 lxc query "$remote:/1.0/resources?target=$n" < /dev/null 2>/dev/null)
        if test -n "$res"
            set threads (printf '%s\n' $res | jq -r '.cpu.total|tostring')
            set mem_bytes (printf '%s\n' $res | jq -r '.memory.total|tostring')
            set mem_total (printf '%s\n' $res | jq -r '.memory.total/1073741824|tostring')
        end

        # Allocated CPU/mem/disk = sum of instance limits on this member
        if test -n "$all"
            set alloc (printf '%s\n' $all | jq -r --arg m "$n" --arg t "$threads" --arg mt "$mem_bytes" '
                def g: {"B":1,"KB":1000,"KiB":1024,"MB":1000000,"MiB":1048576,"GB":1000000000,"GiB":1073741824,"TB":1000000000000,"TiB":1099511627776};
                def fmt: (. * 10 | round / 10 | tostring);
                ([.[] | select(.location == $m) | .config["limits.cpu"] // empty | tonumber? // 0] | add // 0) as $c
                | ([.[] | select(.location == $m) | .config["limits.memory"] // empty | capture("^(?<n>[0-9.]+)(?<u>[KMGT]i?B)?$") // empty | (.n | tonumber) * (g[.u] // 1)] | add // 0) as $mb
                | ([.[] | select(.location == $m) | .devices.root.size // empty | capture("^(?<n>[0-9.]+)(?<u>[KMGT]i?B)?$") // empty | (.n | tonumber) * (g[.u] // 1)] | add // 0) as $db
                | [($c|fmt), ($mb/1073741824|fmt), ($c/($t|tonumber)*1000|round/10), ($mb/($mt|tonumber)*1000|round/10), ($db/1073741824|fmt)] | join("\n")' 2>/dev/null)
            if test -n "$alloc"
                set cpu_alloc $alloc[1]
                set mem_alloc $alloc[2]
                set cpu_pct $alloc[3]
                set mem_pct $alloc[4]
                set disk_alloc $alloc[5]
            end
        end

        # Disk usage per member from the local storage pool resources API
        if test -n "$pool"
            set disk (perl -e 'alarm shift; exec @ARGV' 15 lxc query "$remote:/1.0/storage-pools/$pool/resources?target=$n" < /dev/null 2>/dev/null | jq -r '"disk " + ((.space.used/1073741824*10|round/10)|tostring) + "/" + ((.space.total/1073741824*10|round/10)|tostring) + "GiB used " + ((.space.used/.space.total*1000|round/10)|tostring) + "%"' 2>/dev/null)
            if test -z "$disk"
                set disk '(disk: no response within 15s)'
            end
        end

        # Assemble the line
        if test -n "$cpu_alloc"; and test -n "$threads"
            set line "cpu $cpu_alloc/$threads vCPU alloc ($cpu_pct%)"
        else
            set line "cpu n/a"
        end
        if test -n "$mem_alloc"; and test -n "$mem_total"
            set line "$line   mem $mem_alloc/$mem_total GiB alloc ($mem_pct%)"
        end
        if test -n "$pool"
            if test -n "$disk_alloc"
                set line "$line   $disk ($pool, alloc $disk_alloc GiB)"
            else
                set line "$line   $disk ($pool)"
            end
        end

        printf '%s\n' "$line"
    end

    # ---- Ceph ---------------------------------------------------------------
    # LXD reports 0B for cephobject pools, so real usage comes from Ceph itself,
    # gathered over SSH from the first reachable member (MicroCeph's ceph and
    # radosgw-admin need root). Override the SSH user with $LXD_TOP_SSH_USER.
    test -z "$ceph_pools"; and return 0

    set -l ssh_user ubuntu
    set -q LXD_TOP_SSH_USER; and set ssh_user $LXD_TOP_SSH_USER

    # Emits one JSON object; any failed sub-command degrades to null / [].
    set -l ceph_script '
j() { out=$("$@" -f json 2>/dev/null) && [ -n "$out" ] && printf "%s" "$out" || printf null; }
printf "{\"health\":"; j ceph health
printf ",\"df\":"; j ceph df
printf ",\"osd\":"; j ceph osd df tree
printf ",\"buckets\":"
b=""; command -v radosgw-admin >/dev/null 2>&1 && b=$(radosgw-admin bucket stats 2>/dev/null)
[ -n "$b" ] && printf "%s" "$b" || printf "[]"
printf "}\n"
'
    set -l ceph_json
    set -l ceph_host
    for n in $members
        set ceph_json (printf '%s' $ceph_script | perl -e 'alarm shift; exec @ARGV' 30 ssh -o BatchMode=yes -o ConnectTimeout=5 "$ssh_user@$n" 'sudo -n sh -s' 2>/dev/null | string collect)
        if printf '%s' $ceph_json | jq -e '.df.stats' >/dev/null 2>&1
            set ceph_host $n
            break
        end
        set ceph_json
    end

    if test -z "$ceph_host"
        printf '== ceph (%s) ==\n' (string join ', ' $ceph_pools)
        printf '(no response from ceph via ssh %s@<member> within 30s)\n' $ssh_user
        return 0
    end

    # LXD bucket definitions (for size quotas) across all Ceph object pools
    set -l lxd_buckets (for p in $ceph_pools
            perl -e 'alarm shift; exec @ARGV' 15 lxc query "$remote:/1.0/storage-pools/$p/buckets?all-projects=true&recursion=1" < /dev/null 2>/dev/null
        end | jq -s 'map(. // []) | add // []' 2>/dev/null | string collect)
    test -z "$lxd_buckets"; and set lxd_buckets '[]'

    printf '== ceph (via %s) ==\n' $ceph_host
    printf '%s' $ceph_json | jq -r --argjson lxd "$lxd_buckets" '
        def h: if . == null then "?"
            elif . >= 1099511627776 then "\(. / 1099511627776 * 10 | round / 10)TiB"
            elif . >= 1073741824 then "\(. / 1073741824 * 10 | round / 10)GiB"
            elif . >= 1048576 then "\(. / 1048576 * 10 | round / 10)MiB"
            elif . >= 1024 then "\(. / 1024 * 10 | round / 10)KiB"
            else "\(.)B" end;
        def pct(a; b): if (b // 0) > 0 then "\(a / b * 1000 | round / 10)%" else "n/a" end;
        def pad(w): tostring | if length < w then . + (" " * (w - length)) else . end;
        def g: {"B":1,"KB":1000,"KiB":1024,"MB":1000000,"MiB":1048576,"GB":1000000000,"GiB":1073741824,"TB":1000000000000,"TiB":1099511627776};
        def bytes: capture("^(?<n>[0-9.]+)(?<u>[KMGT]i?B)?$") // null | if . == null then null else (.n | tonumber) * (g[.u] // 1) end;

        .df.stats as $s
        | ("health   " + (.health.status // "?")
            + ([.health.checks // {} | .[] | .summary.message] | if length > 0 then "  (" + join("; ") + ")" else "" end)),
          ("raw      \($s.total_used_raw_bytes | h)/\($s.total_bytes | h) used (\(pct($s.total_used_raw_bytes; $s.total_bytes)))   \($s.total_avail_bytes | h) avail   \($s.num_osds) OSDs"),

          # Per-OSD fill (small OSDs fill up first and gate pool capacity)
          ((.osd.nodes // []) as $nodes
            | ([$nodes[] | select(.type == "host") | .name as $hn | .children[] | {key: tostring, value: $hn}] | from_entries) as $host
            | $nodes[] | select(.type == "osd")
            | "osd      \(.name | pad(7)) \(($host[.id | tostring] // "?") | pad(20)) \((.kb_used * 1024 | h) + "/" + (.kb * 1024 | h) | pad(17)) \("\(.utilization * 10 | round / 10)%" | pad(7)) \(.status)"),

          # Pools that hold data; max_avail already accounts for replication
          (.df.pools // [] | map(select(.stats.stored > 0)) | sort_by(-.stats.stored)[]
            | "pool     \(.name | pad(28)) stored \(.stats.stored | h | pad(9)) objects \(.stats.objects | pad(7)) avail \(.stats.max_avail | h)"),

          # Buckets: RGW usage vs LXD size quota (falls back to RGW quota)
          ((.buckets // []) as $rgw
            | ($lxd | map({key: .name, value: .}) | from_entries) as $lb
            | $rgw | sort_by(.bucket)[]
            | (.usage["rgw.main"].size // 0) as $used
            | (.usage["rgw.main"].num_objects // 0) as $objs
            | $lb[.bucket] as $l
            | (($l.config.size // "" | bytes) // (if .bucket_quota.enabled and .bucket_quota.max_size > 0 then .bucket_quota.max_size else null end)) as $quota
            | "bucket   \((if $l then $l.project + "/" else "" end) + .bucket | pad(28)) "
              + (if $quota then "\(($used | h) + "/" + ($quota | h) | pad(17)) \(pct($used; $quota) | pad(7))" else "\($used | h | pad(17)) \("no quota" | pad(7))" end)
              + " \($objs) objects")
    '
end
