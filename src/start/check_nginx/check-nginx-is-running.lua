--- 读取nginx.pid，检测nginx是否在运行中 调试脚本
--- 调用系统命令函数调试脚本

---read_file 读取文件，返回文件描述符
---@param file_path string 文件路径
---@return string 文件描述符
local function read_file(file_path)
    local file, err = io.open(file_path, "rb")
    if not file then
        return false, "failed to open file: " .. file_path .. ", error info:" .. err
    end

    local data = file:read("*all")
    file:close()
    return data
end

---read_nginx_pid 读取nginx.pid，校验nginx是否在运行
---@param nginx_pid_path string
local function read_nginx_pid(nginx_pid_path)
    local pid, err = read_file(nginx_pid_path)
    if pid then
        local hd = io.popen("lsof -p " .. pid)
        local res = hd:read("*a")
        if res and res ~= "" then
            print("APISIX is running...")
            return nil
        end
    end
end

---excute_cmd 执行脚本命令
---@param cmd string 脚本命令
---@return string 返回文件描述符
local function excute_cmd(cmd)
    local t, err = io.popen(cmd)
    if not t then
        return nil, "failed to execute command: " .. cmd .. ", error info:" .. err
    end
    local data = t:read("*all")
    t:close()
    print("data" .. data)
    return data
end

--调试lua执行系统命令开始位置
local cmd_result, err = excute_cmd("pwd")
if not cmd_result then
    print("failed to excute cmd: " .. err)
end
print("excute cmd 'pwd': " .. cmd_result)

--调试lua执行系统命令开始位置
read_nginx_pid("/usr/local/Cellar/apisix/apache-apisix-1.5/logs/nginx.pid")
