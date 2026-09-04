function lxc-nodes --description 'Per-member allocated CPU/mem + disk usage for an LXD/MicroCloud cluster'
    set -l remote $argv[1]
    if test -z "$remote"
        set remote microcloud
    end

    # List cluster members. Every lxc call is guarded by a perl alarm so an
    # unreachable remote (lxc retries with backoff and can block for ages)
    # cannot hang the command.
    set -l members (perl -e 'alarm shift; exec @ARGV' 20 lxc cluster list "$remote:" -f csv < /dev/null 2>/dev/null | cut -d, -f1)
    if test -z "$members"
        echo "error: no response from remote '$remote' within 20s" >&2
        return 1
    end

    # All instances across all projects, once (allocations are summed per member)
    set -l all (perl -e 'alarm shift; exec @ARGV' 30 lxc query "$remote:/1.0/instances?all-projects=true&recursion=1" < /dev/null 2>/dev/null)

    # First storage pool on the remote (disk usage is reported per pool)
    set -l pool (perl -e 'alarm shift; exec @ARGV' 15 lxc query "$remote:/1.0/storage-pools" < /dev/null 2>/dev/null | jq -r '.[0] | split("/")[-1]' 2>/dev/null)
    if test -z "$pool"
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

        # Disk usage per member from the storage pool resources API
        set disk (perl -e 'alarm shift; exec @ARGV' 15 lxc query "$remote:/1.0/storage-pools/$pool/resources?target=$n" < /dev/null 2>/dev/null | jq -r '"disk " + ((.space.used/1073741824*10|round/10)|tostring) + "/" + ((.space.total/1073741824*10|round/10)|tostring) + "GiB used " + ((.space.used/.space.total*1000|round/10)|tostring) + "%"' 2>/dev/null)
        if test -z "$disk"
            set disk '(disk: no response within 15s)'
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
        if test -n "$disk_alloc"
            set line "$line   $disk ($pool, alloc $disk_alloc GiB)"
        else
            set line "$line   $disk ($pool)"
        end

        printf '%s\n' "$line"
    end
end
