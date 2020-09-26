---读取yaml配置调试脚本，重点可以关注一下tinyyaml是如何解析yaml文件的
---下面加的这一段路径必须要包含tinyyaml模块，即tinyyaml.lua所在位置
package.path = package.path .. ";/usr/local/Cellar/apisix/apache-apisix-1.5/deps/share/lua/5.1/?.lua"

local yaml = require("tinyyaml")

--local inspect = require("inspect")

local _M = {}

---read_file 读取文件，返回文件描述符
---@param file_path string 文件路径
---@return string 文件描述符
local function read_file(file_path)
    --file = io.open(filename [, mode])
    --r	只读，文件必须存在。默认。
    --b	二进制模式，与r/w/a结合使用。
    local file, err = io.open(file_path, "rb")
    if not file then
        return false, "failed to open file: " .. file_path .. ", error info:" .. err
    end

    local data = file:read("*all")
    file:close()
    return data
end

---read_yaml_conf
---@param yaml_conf_path string yaml文件绝对路径
---@return table yaml文件解析之后的table
function _M.read_yaml_conf(self, yaml_conf_path)
    local ymal_conf, err = read_file(yaml_conf_path)
    if not ymal_conf then
        return nil, err
    end
    --调用tinyyaml来解析
    return yaml.parse(ymal_conf)
end

--调试开始位置，预先要知道调试yaml配置文件的绝对路径，作为参数传入
--local yaml_conf, err = read_yaml_conf("/usr/local/Cellar/apisix/apache-apisix-1.5/conf/config.yaml")
--if not yaml_conf then
--    print("failed to read local yaml config : " .. err)
--end

return _M
--print("-------yaml config start-------\n")
--print(inspect(yaml_conf))
--print("\n-------yaml config end-------")
