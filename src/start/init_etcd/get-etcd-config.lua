local read_config_yaml_file = require("start.read_config.read-config-yaml-file")

local function excute_cmd(cmd)
    local t, err = io.popen(cmd)
    if not t then
        return nil, "failed to execute command: " .. cmd .. ", error info:" .. err
    end
    local data = t:read("*all")
    t:close()
    return data
end

local function get_etcd_conf()

    local yaml_conf, err = read_config_yaml_file:read_yaml_conf("/usr/local/Cellar/apisix/apache-apisix-1.5/conf/config.yaml")

    if not yaml_conf then
        error("failed to read local yaml config of apisix: " .. err)
    end

    if not yaml_conf.apisix then
        error("failed to read `apisix` field from yaml file when init etcd")
    end

    if yaml_conf.apisix.config_center ~= "etcd" then
        return true
    end

    if not yaml_conf.etcd then
        error("failed to read `etcd` field from yaml file when init etcd")
    end

    local etcd_conf = yaml_conf.etcd

    return etcd_conf, yaml_conf

end

local function connect_etcd()
    local etcd_conf, yaml_conf = get_etcd_conf()
    local timeout = etcd_conf.timeout or 3
    local uri
    --convert old single etcd config to multiple etcd config
    if type(yaml_conf.etcd.host) == "string" then
        yaml_conf.etcd.host = { yaml_conf.etcd.host }
    end

    local host_count = #(yaml_conf.etcd.host)

    -- check whether the user has enabled etcd v2 protocol
    for index, host in ipairs(yaml_conf.etcd.host) do
        uri = host .. "/v2/keys"
        local cmd = "curl -i -m " .. timeout * 2 .. " -o /dev/null -s -w %{http_code} " .. uri
        local res = excute_cmd(cmd)
        if res == "404" then
            io.stderr:write(string.format("failed: please make sure that you have enabled the v2 protocol of etcd on %s.\n", host))
            return
        end
    end

end

local function init_etcd_structure()
    local etcd_conf, yaml_conf = get_etcd_conf()
    local timeout = etcd_conf.timeout or 3
    local etcd_ok = false
    for index, host in ipairs(yaml_conf.etcd.host) do

        local is_success = true
        uri = host .. "/v2/keys" .. ("/apiseven" or "")

        for _, dir_name in ipairs({"/routes", "/upstreams", "/services",
                                   "/plugins", "/consumers", "/node_status",
                                   "/ssl", "/global_rules", "/stream_routes",
                                   "/proto"}) do
            local cmd = "curl " .. uri .. dir_name
                    .. "?prev_exist=false -X PUT -d dir=true "
                    .. "--connect-timeout " .. timeout
                    .. " --max-time " .. timeout * 2 .. " --retry 1 2>&1"

            local res = excute_cmd(cmd)
            if not res:find("index", 1, true)
                    and not res:find("createdIndex", 1, true) then
                is_success = false
                if (index == host_count) then
                    error(cmd .. "\n" .. res)
                end
                break
            end

            if show_output then
                print(cmd)
                print(res)
            end
        end

        if is_success then
            etcd_ok = true
            break
        end
    end

    if not etcd_ok then
        error("none of the configured etcd works well")
    end
end
--connect_etcd()
init_etcd_structure()



