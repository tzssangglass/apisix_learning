package.path = package.path .. ";/usr/local/Cellar/apisix/apache-apisix-1.5/deps/share/lua/5.1/?.lua;/usr/local/Cellar/apisix/apache-apisix-1.5/deps/share/lua/5.1/?/?.lua"

local template = require("resty.template")
local ngx_tpl = [=[
# Configuration File - Nginx Server Configs
# This is a read-only file, do not try to modify it.

master_process on;

worker_processes {* worker_processes *};
{% if os_name == "Linux" then %}
worker_cpu_affinity auto;
{% end %}

error_log {* error_log *} {* error_log_level or "error" *};
pid logs/nginx.pid;

worker_rlimit_nofile {* worker_rlimit_nofile *};

events {
    accept_mutex off;
    worker_connections {* event.worker_connections *};
}

worker_rlimit_core  {* worker_rlimit_core *};

worker_shutdown_timeout {* worker_shutdown_timeout *};

env APISIX_PROFILE;

{% if stream_proxy then %}
stream {
    lua_package_path  "$prefix/deps/share/lua/5.1/?.lua;$prefix/deps/share/lua/5.1/?/init.lua;]=]
        .. [=[{*apisix_lua_home*}/?.lua;{*apisix_lua_home*}/?/init.lua;;{*lua_path*};";
    lua_package_cpath "$prefix/deps/lib64/lua/5.1/?.so;]=]
        .. [=[$prefix/deps/lib/lua/5.1/?.so;;]=]
        .. [=[{*lua_cpath*};";
    lua_socket_log_errors off;

    lua_shared_dict lrucache-lock-stream   10m;

    resolver {% for _, dns_addr in ipairs(dns_resolver or {}) do %} {*dns_addr*} {% end %} valid={*dns_resolver_valid*};
    resolver_timeout {*resolver_timeout*};

    upstream apisix_backend {
        server 127.0.0.1:80;
        balancer_by_lua_block {
            apisix.stream_balancer_phase()
        }
    }

    init_by_lua_block {
        require "resty.core"
        apisix = require("apisix")
        apisix.stream_init()
    }

    init_worker_by_lua_block {
        apisix.stream_init_worker()
    }

    server {
        {% for _, port in ipairs(stream_proxy.tcp or {}) do %}
        listen {*port*} {% if enable_reuseport then %} reuseport {% end %} {% if proxy_protocol and proxy_protocol.enable_tcp_pp then %} proxy_protocol {% end %};
        {% end %}
        {% for _, port in ipairs(stream_proxy.udp or {}) do %}
        listen {*port*} udp {% if enable_reuseport then %} reuseport {% end %};
        {% end %}

        {% if proxy_protocol and proxy_protocol.enable_tcp_pp_to_upstream then %}
        proxy_protocol on;
        {% end %}

        preread_by_lua_block {
            apisix.stream_preread_phase()
        }

        proxy_pass apisix_backend;

        log_by_lua_block {
            apisix.stream_log_phase()
        }
    }
}
{% end %}

http {
    lua_package_path  "$prefix/deps/share/lua/5.1/?.lua;$prefix/deps/share/lua/5.1/?/init.lua;]=]
        .. [=[{*apisix_lua_home*}/?.lua;{*apisix_lua_home*}/?/init.lua;;{*lua_path*};";
    lua_package_cpath "$prefix/deps/lib64/lua/5.1/?.so;]=]
        .. [=[$prefix/deps/lib/lua/5.1/?.so;;]=]
        .. [=[{*lua_cpath*};";

    lua_shared_dict plugin-limit-req     10m;
    lua_shared_dict plugin-limit-count   10m;
    lua_shared_dict prometheus-metrics   10m;
    lua_shared_dict plugin-limit-conn    10m;
    lua_shared_dict upstream-healthcheck 10m;
    lua_shared_dict worker-events        10m;
    lua_shared_dict lrucache-lock        10m;
    lua_shared_dict skywalking-tracing-buffer    100m;


    # for openid-connect plugin
    lua_shared_dict discovery             1m; # cache for discovery metadata documents
    lua_shared_dict jwks                  1m; # cache for JWKs
    lua_shared_dict introspection        10m; # cache for JWT verification results

    # for custom shared dict
    {% if http.lua_shared_dicts then %}
    {% for cache_key, cache_size in pairs(http.lua_shared_dicts) do %}
    lua_shared_dict {*cache_key*} {*cache_size*};
    {% end %}
    {% end %}

    {% if proxy_cache then %}
    # for proxy cache
    {% for _, cache in ipairs(proxy_cache.zones) do %}
    proxy_cache_path {* cache.disk_path *} levels={* cache.cache_levels *} keys_zone={* cache.name *}:{* cache.memory_size *} inactive=1d max_size={* cache.disk_size *};
    {% end %}
    {% end %}

    {% if proxy_cache then %}
    # for proxy cache
    map $upstream_cache_zone $upstream_cache_zone_info {
    {% for _, cache in ipairs(proxy_cache.zones) do %}
        {* cache.name *} {* cache.disk_path *},{* cache.cache_levels *};
    {% end %}
    }
    {% end %}

    lua_ssl_verify_depth 5;
    ssl_session_timeout 86400;

    {% if http.underscores_in_headers then %}
    underscores_in_headers {* http.underscores_in_headers *};
    {%end%}

    lua_socket_log_errors off;

    resolver {% for _, dns_addr in ipairs(dns_resolver or {}) do %} {*dns_addr*} {% end %} valid={*dns_resolver_valid*};
    resolver_timeout {*resolver_timeout*};

    lua_http10_buffering off;

    lua_regex_match_limit 100000;
    lua_regex_cache_max_entries 8192;

    log_format main '$remote_addr - $remote_user [$time_local] $http_host "$request" $status $body_bytes_sent $request_time "$http_referer" "$http_user_agent" $upstream_addr $upstream_status $upstream_response_time';

    access_log {* http.access_log *} main buffer=16384 flush=3;
    open_file_cache  max=1000 inactive=60;
    client_max_body_size 0;
    keepalive_timeout {* http.keepalive_timeout *};
    client_header_timeout {* http.client_header_timeout *};
    client_body_timeout {* http.client_body_timeout *};
    send_timeout {* http.send_timeout *};

    server_tokens off;
    more_set_headers 'Server: APISIX web server';

    include mime.types;
    charset utf-8;

    {% if real_ip_header then %}
    real_ip_header {* real_ip_header *};
    {% print("\nDeprecated: apisix.real_ip_header has been moved to nginx_config.http.real_ip_header. apisix.real_ip_header will be removed in the future version. Please use nginx_config.http.real_ip_header first.\n\n") %}
    {% elseif http.real_ip_header then %}
    real_ip_header {* http.real_ip_header *};
    {% end %}

    {% if real_ip_from then %}
    {% print("\nDeprecated: apisix.real_ip_from has been moved to nginx_config.http.real_ip_from. apisix.real_ip_from will be removed in the future version. Please use nginx_config.http.real_ip_from first.\n\n") %}
    {% for _, real_ip in ipairs(real_ip_from) do %}
    set_real_ip_from {*real_ip*};
    {% end %}
    {% elseif http.real_ip_from then %}
    {% for _, real_ip in ipairs(http.real_ip_from) do %}
    set_real_ip_from {*real_ip*};
    {% end %}
    {% end %}

    upstream apisix_backend {
        server 0.0.0.1;
        balancer_by_lua_block {
            apisix.http_balancer_phase()
        }

        keepalive 320;
    }

    init_by_lua_block {
        require "resty.core"
        apisix = require("apisix")

        local dns_resolver = { {% for _, dns_addr in ipairs(dns_resolver or {}) do %} "{*dns_addr*}", {% end %} }
        local args = {
            dns_resolver = dns_resolver,
        }
        apisix.http_init(args)
    }

    init_worker_by_lua_block {
        apisix.http_init_worker()
    }

    {% if enable_admin and port_admin then %}
    server {
        {%if https_admin then%}
        listen {* port_admin *} ssl;

        {%if admin_api_mtls and admin_api_mtls.admin_ssl_cert and admin_api_mtls.admin_ssl_cert ~= "" and
         admin_api_mtls.admin_ssl_cert_key and admin_api_mtls.admin_ssl_cert_key ~= "" and
         admin_api_mtls.admin_ssl_ca_cert and admin_api_mtls.admin_ssl_ca_cert ~= ""
        then%}
        ssl_verify_client on;
        ssl_certificate      {* admin_api_mtls.admin_ssl_cert *};
        ssl_certificate_key  {* admin_api_mtls.admin_ssl_cert_key *};
        ssl_client_certificate {* admin_api_mtls.admin_ssl_ca_cert *};
        {% else %}
        ssl_certificate      cert/apisix_admin_ssl.crt;
        ssl_certificate_key  cert/apisix_admin_ssl.key;
        {%end%}

        ssl_session_cache    shared:SSL:20m;
        ssl_protocols {* ssl.ssl_protocols *};
        ssl_ciphers {* ssl.ssl_ciphers *};
        ssl_prefer_server_ciphers on;

        {% else %}
        listen {* port_admin *};
        {%end%}
        log_not_found off;
        location /apisix/admin {
            {%if allow_admin then%}
                {% for _, allow_ip in ipairs(allow_admin) do %}
                allow {*allow_ip*};
                {% end %}
                deny all;
            {%end%}

            content_by_lua_block {
                apisix.http_admin()
            }
        }

        location /apisix/dashboard {
            {%if allow_admin then%}
                {% for _, allow_ip in ipairs(allow_admin) do %}
                allow {*allow_ip*};
                {% end %}
                deny all;
            {%end%}

            alias dashboard/;

            try_files $uri $uri/index.html /index.html =404;
        }

        location =/robots.txt {
            return 200 'User-agent: *\nDisallow: /';
        }
    }
    {% end %}

    server {
        listen {* node_listen *} {% if enable_reuseport then %} reuseport {% end %};
        {% if ssl.enable then %}
        listen {* ssl.listen_port *} ssl {% if ssl.enable_http2 then %} http2 {% end %} {% if enable_reuseport then %} reuseport {% end %};
        {% end %}

        {% if proxy_protocol and proxy_protocol.listen_http_port then %}
        listen {* proxy_protocol.listen_http_port *} proxy_protocol;
        {% end %}
        {% if proxy_protocol and proxy_protocol.listen_https_port then %}
        listen {* proxy_protocol.listen_https_port *} ssl {% if ssl.enable_http2 then %} http2 {% end %} proxy_protocol;
        {% end %}

        {% if enable_ipv6 then %}
        listen [::]:{* node_listen *} {% if enable_reuseport then %} reuseport {% end %};
        {% if ssl.enable then %}
        listen [::]:{* ssl.listen_port *} ssl {% if ssl.enable_http2 then %} http2 {% end %} {% if enable_reuseport then %} reuseport {% end %};
        {% end %}
        {% end %} {% -- if enable_ipv6 %}

        ssl_certificate      cert/apisix.crt;
        ssl_certificate_key  cert/apisix.key;
        ssl_session_cache    shared:SSL:20m;
        ssl_session_timeout 10m;

        ssl_protocols {* ssl.ssl_protocols *};
        ssl_ciphers {* ssl.ssl_ciphers *};
        ssl_prefer_server_ciphers on;

        {% if with_module_status then %}
        location = /apisix/nginx_status {
            allow 127.0.0.0/24;
            deny all;
            access_log off;
            stub_status;
        }
        {% end %}

        {% if enable_admin and not port_admin then %}
        location /apisix/admin {
            {%if allow_admin then%}
                {% for _, allow_ip in ipairs(allow_admin) do %}
                allow {*allow_ip*};
                {% end %}
                deny all;
            {%end%}

            content_by_lua_block {
                apisix.http_admin()
            }
        }

        location /apisix/dashboard {
            {%if allow_admin then%}
                {% for _, allow_ip in ipairs(allow_admin) do %}
                allow {*allow_ip*};
                {% end %}
                deny all;
            {%end%}

            alias dashboard/;

            try_files $uri $uri/index.html /index.html =404;
        }
        {% end %}

        ssl_certificate_by_lua_block {
            apisix.http_ssl_phase()
        }

        location / {
            set $upstream_mirror_host        '';
            set $upstream_scheme             'http';
            set $upstream_host               $host;
            set $upstream_upgrade            '';
            set $upstream_connection         '';
            set $upstream_uri                '';

            access_by_lua_block {
                apisix.http_access_phase()
            }

            proxy_http_version 1.1;
            proxy_set_header   Host              $upstream_host;
            proxy_set_header   Upgrade           $upstream_upgrade;
            proxy_set_header   Connection        $upstream_connection;
            proxy_set_header   X-Real-IP         $remote_addr;
            proxy_pass_header  Server;
            proxy_pass_header  Date;

            ### the following x-forwarded-* headers is to send to upstream server

            set $var_x_forwarded_for        $remote_addr;
            set $var_x_forwarded_proto      $scheme;
            set $var_x_forwarded_host       $host;
            set $var_x_forwarded_port       $server_port;

            if ($http_x_forwarded_for != "") {
                set $var_x_forwarded_for "${http_x_forwarded_for}, ${realip_remote_addr}";
            }
            if ($http_x_forwarded_proto != "") {
                set $var_x_forwarded_proto $http_x_forwarded_proto;
            }
            if ($http_x_forwarded_host != "") {
                set $var_x_forwarded_host $http_x_forwarded_host;
            }
            if ($http_x_forwarded_port != "") {
                set $var_x_forwarded_port $http_x_forwarded_port;
            }

            proxy_set_header   X-Forwarded-For      $var_x_forwarded_for;
            proxy_set_header   X-Forwarded-Proto    $var_x_forwarded_proto;
            proxy_set_header   X-Forwarded-Host     $var_x_forwarded_host;
            proxy_set_header   X-Forwarded-Port     $var_x_forwarded_port;

            {% if proxy_cache then %}
            ###  the following configuration is to cache response content from upstream server

            set $upstream_cache_zone            off;
            set $upstream_cache_key             '';
            set $upstream_cache_bypass          '';
            set $upstream_no_cache              '';
            set $upstream_hdr_expires           '';
            set $upstream_hdr_cache_control     '';

            proxy_cache                         $upstream_cache_zone;
            proxy_cache_valid                   any {% if proxy_cache.cache_ttl then %} {* proxy_cache.cache_ttl *} {% else %} 10s {% end %};
            proxy_cache_min_uses                1;
            proxy_cache_methods                 GET HEAD;
            proxy_cache_lock_timeout            5s;
            proxy_cache_use_stale               off;
            proxy_cache_key                     $upstream_cache_key;
            proxy_no_cache                      $upstream_no_cache;
            proxy_cache_bypass                  $upstream_cache_bypass;

            proxy_hide_header                   Cache-Control;
            proxy_hide_header                   Expires;
            add_header      Cache-Control       $upstream_hdr_cache_control;
            add_header      Expires             $upstream_hdr_expires;
            add_header      Apisix-Cache-Status $upstream_cache_status always;
            {% end %}

            proxy_pass      $upstream_scheme://apisix_backend$upstream_uri;
            mirror          /proxy_mirror;

            header_filter_by_lua_block {
                apisix.http_header_filter_phase()
            }

            body_filter_by_lua_block {
                apisix.http_body_filter_phase()
            }

            log_by_lua_block {
                apisix.http_log_phase()
            }
        }

        location @grpc_pass {

            access_by_lua_block {
                apisix.grpc_access_phase()
            }

            grpc_set_header   Content-Type application/grpc;
            grpc_socket_keepalive on;
            grpc_pass         grpc://apisix_backend;

            header_filter_by_lua_block {
                apisix.http_header_filter_phase()
            }

            body_filter_by_lua_block {
                apisix.http_body_filter_phase()
            }

            log_by_lua_block {
                apisix.http_log_phase()
            }
        }

        location = /proxy_mirror {
            internal;

            if ($upstream_mirror_host = "") {
                return 200;
            }

            proxy_pass $upstream_mirror_host$request_uri;
        }
    }
}
]=]

local prepare_sys_conf_env = require("start.prepare_sys_conf.prepare_sys_conf_env")

local function excute_cmd(cmd)
    local t, err = io.popen(cmd)
    if not t then
        return nil, "failed to execute command: " .. cmd .. ", error info:" .. err
    end
    local data = t:read("*all")
    t:close()
    return data
end

local function write_file(file_path, data)
    local file, err = io.open(file_path, "w+")
    if not file then
        return false, "failed to open file: " .. file_path .. ", error info:" .. err
    end

    file:write(data)
    file:close()
    return true
end

local function get_openresty_version()
    local str = "nginx version: openresty/"
    local ret = excute_cmd("openresty -v 2>&1")
    local pos = string.find(ret,str)
    if pos then
        return string.sub(ret, pos + string.len(str))
    end

    str = "nginx version: nginx/"
    ret = excute_cmd("openresty -v 2>&1")
    pos = string.find(ret, str)
    if pos then
        return string.sub(ret, pos + string.len(str))
    end

    return nil
end

local function split(self, sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

local function check_or_version(cur_ver_s, need_ver_s)
    local cur_vers = split(cur_ver_s, [[.]])
    local need_vers = split(need_ver_s, [[.]])
    local len = math.max(#cur_vers, #need_vers)

    for i = 1, len do
        local cur_ver = tonumber(cur_vers[i]) or 0
        local need_ver = tonumber(need_vers[i]) or 0
        if cur_ver > need_ver then
            return true
        end

        if cur_ver < need_ver then
            return false
        end
    end

    return true
end

local function compile()
    local sys_conf = prepare_sys_conf_env:prepare()
    local conf_render = template.compile(ngx_tpl)
    local ngxconf = conf_render(sys_conf)

    local ok, err = write_file("./" .. "nginx.conf", ngxconf)
    if not ok then
        error("failed to update nginx.conf: " .. err)
    end

    local op_ver = get_openresty_version()
    if op_ver == nil then
        io.stderr:write("can not find openresty\n")
        return
    end

    local need_ver = "1.15.8"
    if not check_or_version(op_ver, need_ver) then
        io.stderr:write("openresty version must >=", need_ver, " current ", op_ver, "\n")
        return
    end

end

local _ = compile()
