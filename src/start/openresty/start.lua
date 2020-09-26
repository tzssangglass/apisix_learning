local apisix_home = "/usr/local/Cellar/apisix/apache-apisix-1.5"

local openresty_args = [[openresty  -p ]] .. apisix_home .. [[ -c ]]
        .. apisix_home .. [[/conf/nginx.conf]]

function start()

    local cmd = openresty_args
     print(cmd)
    --os.execute(cmd)
end

start()