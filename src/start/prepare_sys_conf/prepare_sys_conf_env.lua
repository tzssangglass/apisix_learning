local read_config_yaml_file = require("start.read_config.read-config-yaml-file")
local pkg_cpath_org = package.cpath
local pkg_path_org = package.path
--local inspect = require("inspect")

local _M = {}

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Note: The `excute_cmd` return value will have a line break at the end,
-- it is recommended to use the `trim` function to handle the return value.
local function excute_cmd(cmd)
    local t, err = io.popen(cmd)
    if not t then
        return nil, "failed to execute command: " .. cmd .. ", error info:" .. err
    end
    local data = t:read("*all")
    t:close()
    return data
end

local function local_dns_resolver(file_path)
    local file, err = io.open(file_path, "rb")
    if not file then
        return false, "failed to open file: " .. file_path .. ", error info:" .. err
    end
    local dns_addrs = {}
    for line in file:lines() do
        local addr, n = line:gsub("^nameserver%s+(%d+%.%d+%.%d+%.%d+)%s*$", "%1")
        if n == 1 then
            table.insert(dns_addrs, addr)
        end
    end
    file:close()
    return dns_addrs
end

local function is_32bit_arch()
    local ok, ffi = pcall(require, "ffi")
    if ok then
        -- LuaJIT
        return ffi.abi("32bit")
    end
    local ret = excute_cmd("getconf LONG_BIT")
    local bits = tonumber(ret)
    return bits <= 32
end

function _M.prepare()
    local sys_conf = {
        lua_path = pkg_path_org,
        lua_cpath = pkg_cpath_org,
        os_name = trim(excute_cmd("uname")),
        apisix_lua_home = "/usr/local/Cellar/apisix/apache-apisix-1.5",
        with_module_status = true,
        error_log = { level = "warn" },
    }
    local yaml_conf, _ = read_config_yaml_file:read_yaml_conf("/usr/local/Cellar/apisix/apache-apisix-1.5/conf/config.yaml")

    if not yaml_conf.apisix then
        error("failed to read `apisix` field from yaml file")
    end

    if not yaml_conf.nginx_config then
        error("failed to read `nginx_config` field from yaml file")
    end

    if is_32bit_arch() then
        sys_conf["worker_rlimit_core"] = "4G"
    else
        sys_conf["worker_rlimit_core"] = "16G"
    end

    for k, v in pairs(yaml_conf.apisix) do
        sys_conf[k] = v
    end
    for k, v in pairs(yaml_conf.nginx_config) do
        sys_conf[k] = v
    end

    local wrn = sys_conf["worker_rlimit_nofile"]
    local wc = sys_conf["event"]["worker_connections"]
    if not wrn or wrn <= wc then
        -- ensure the number of fds is slightly larger than the number of conn
        sys_conf["worker_rlimit_nofile"] = wc + 128
    end

    if (sys_conf["enable_dev_mode"] == true) then
        sys_conf["worker_processes"] = 1
        sys_conf["enable_reuseport"] = false
    else
        sys_conf["worker_processes"] = "auto"
    end

    local dns_resolver = sys_conf["dns_resolver"]
    if not dns_resolver or #dns_resolver == 0 then
        local dns_addrs, err = local_dns_resolver("/etc/resolv.conf")
        if not dns_addrs then
            error("failed to import local DNS: " .. err)
        end

        if #dns_addrs == 0 then
            error("local DNS is empty")
        end
        sys_conf["dns_resolver"] = dns_addrs
    end
    return sys_conf
end

return _M

--print("-------yaml config start-------\n")
--print(inspect(sys_conf))
--print("\n-------yaml config end-------")