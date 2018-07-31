local component = require("component")
if not component.isAvailable("internet") then
    io.stderr:write("spm-error: Internet card not available, internet access is required")
    os.exit()
end
local internet = require("internet")
wget = loadfile("/bin/wget.lua")
local serialization = require("serialization")
local fs = require("filesystem")
local text = require("text")
local shell = require("shell")
local term = require("term")

local PACKAGES_F = "packages.cfg"
local SETTINGS = "/etc/spm.cfg"

local function printUsage()
    print("Simple Package Manager (spm)")
    print("List of commands and parameters (<> = required, [] = optional):")
    print("-----------------------------------------------------------------------------------")
    print("addrepo <url> \t\t\t Add repository")
    print("removerepo <url> \t\t Remove repository")
    print("listrepo \t\t\t List all repositories")
    print("search [packageName] \t\t List all packages from repositories, or search a package")
    print("query [packageName] \t\t List all installed packages, or query for an installed package")
    print("update [-r] [packageName] \t Update everything or the given package (-r:reboot)")
    print("install [-f, -r] <packageName> \t Install package (-f:force installation, -r:reboot)")
    print("remove [-f] <packageName> \t Remove package (-f:force remove dependencies)")
end

local function __concatUrl(repo, file)
    if repo[#repo] ~= '/' then
        repo = repo.."/"
    end
    if file[1] == '/' then
        file = string.sub(file, 2)
    end
    return text.trim(repo..file)
end

local function __getContent(url)
    local result, response = pcall(internet.request, url)
    if result then
        local content = ""
        for chunk in response do
            content = content..chunk
        end
        return serialization.unserialize(text.trim(content))
    end
    return nil
end

local function __downloadFile(url, path)
    -- Auto-force because why not
    return wget("-fq",url,path)
end

local function __readCfg(filepath, default)
    local file, emsg = io.open(filepath, "rb")
    if not file then
        if default ~= nil then
            return default
        else
            io.stderr:write("spm-error: Cannot read file at path " .. filepath .. ": " .. emsg)
            return nil
        end
    end
    local sdata = file:read("*a")
    file:close()
    return serialization.unserialize(sdata) or nil
end

local function __writeCfg(filepath, data)
    if not fs.exists(fs.path(filepath)) then
        fs.makeDirectory(fs.path(filepath))
    end
    local file, emsg = io.open(filepath, "wb")
    if not file then
        io.stderr:write("spm-error: Cannot write file to path " .. filepath .. ": " .. emsg)
        return
    end
    local sdata = serialization.serialize(data)
    file:write(sdata)
    file:close()
end

local function __tryFindRepo(repositoryUrl, packageName)
    local url = __concatUrl(repositoryUrl, PACKAGES_F)
    local success, content = pcall(__getContent, url)
    if not success or not content then
        return nil
    end
    if packageName == nil then
        return content
    else
        for k,p in pairs(content) do
            if k == packageName then
                return p
            end
        end
    end
end

local function __tryFindFile(packageName, settings)
    if settings and settings["packages"] then
        if packageName == nil then
            return settings["packages"]
        end
        for k,p in pairs(settings["packages"]) do
            if k == packageName then
                return p
            end
        end
    end
    return nil
end

local function __tryFindDependencies(packageName, settings)
    if settings and settings["packages"] and packageName then
        local result = {}
        local found = false
        for name,pack in pairs(settings["packages"]) do
            if pack["dependencies"] then
                for i = 1, #pack["dependencies"], 1 do
                    if pack["dependencies"][i] == packageName then
                        found = true
                        table.insert(result, name)
                    end
                end
            end
        end
        if found then
            return result
        else
            return nil
        end
    end
    return nil
end

local function __getPack(packageName, settings, force, ignoreDependencies)
    if packageName then
        local package = __tryFindFile(packageName, settings)
        if package and not force then
            print("spm: Package '"..packageName.."' already installed")
            return false
        end
        for i,repo in ipairs(settings["repos"]) do
            package = __tryFindRepo(repo, packageName)
            if package then
                print("spm: Installing '"..packageName.."'...")
                settings["packages"][packageName] = {["files"]={}}
                for dpath,installDir in pairs(package["files"]) do
                    local rpath = __concatUrl(repo,dpath)
                    local filename = fs.name(dpath)
                    local filepath = fs.concat(installDir, filename)
                    print("spm: Copying '"..rpath.."' to '"..filepath.."'...")
                    local success, response = pcall(__downloadFile, rpath, filepath)
                    if success then
                        table.insert(settings["packages"][packageName]["files"], filepath)
                    else
                        io.stderr:write("spm-error: Error installing '"..packageName.."', file '"..dpath.."'. Aborting...")
                        -- TODO: Revert changes
                        return false
                    end
                end
                if package["dependencies"] and not ignoreDependencies then
                    print("spm: Installing dependencies...")
                    settings["packages"][packageName]["dependencies"] = {}
                    for i = 1, #package["dependencies"], 1 do
                        table.insert(settings["packages"][packageName]["dependencies"], package["dependencies"][i])
                        __getPack(package["dependencies"][i], settings, false)
                    end
                end
                print("spm: Package '"..packageName.."' installed succesfully.")
                return true
            end
        end
        io.stderr:write("spm-error: No packages found with name '"..packageName.."'")
        return false
    end
end

local function __deletePack(packageName, settings, force, ignoreDependencies)
    if packageName then
        local package = __tryFindFile(packageName, settings)
        if package then
            print("spm: Removing '"..packageName.."'...")
            for i,v in ipairs(package["files"]) do
                print("spm: Removing file '"..v.."'...")
                fs.remove(v)
            end
            settings["packages"][packageName] = nil
            if package["dependencies"] and not ignoreDependencies then
                if force then
                    print("spm: Removing all '"..packageName.."' dependencies...")
                else
                    print("spm: Removing unused '"..packageName.."' dependencies...")
                end
                for i = 1, #package["dependencies"], 1 do
                    if force then
                        __deletePack(package["dependencies"][i], settings, false)
                    else
                        local deps = __tryFindDependencies(package["dependencies"][i], settings)
                        if not deps or #deps == 0 then
                            __deletePack(package["dependencies"][i], settings, false)
                        end
                    end
                end
            end
            print("spm: Package '"..packageName.."' removed succesfully")
            return true
        end
        io.stderr:write("spm-error: No packages found with name '"..packageName.."'")
        return false
    end
end

local function addRepository(repositoryUrl)
    -- Look for packages.cfg in given url, if found write it to settings
    local url = __concatUrl(repositoryUrl, PACKAGES_F)
    print(url)
    local success, content = pcall(__getContent, url)
    if success then
        local settings = __readCfg(SETTINGS, {["repos"]={}, ["packages"]={}})
        if settings["repos"] ~= nil then
            for i = 1, #settings["repos"], 1 do
                if repositoryUrl == settings["repos"][i] then
                    print("spm: Repository '"..repositoryUrl.."' already exists")
                    return
                end
            end
        end
        table.insert(settings["repos"], repositoryUrl)
        print("spm: Added repository '"..repositoryUrl.."'")
        __writeCfg(SETTINGS, settings)
        return
    else
        io.stderr:write("spm-error: Repository '"..repositoryUrl.."' is invalid")
    end
end

local function removeRepository(repositoryUrl)
    -- Look for url in settings, if found delete it
    local settings = __readCfg(SETTINGS, nil)
    if settings then
        for i,v in ipairs(settings["repos"]) do
            if repositoryUrl == v then
                found = true
                table.remove(settings["repos"], i)
                print("spm: Removed repository '"..repositoryUrl.."'")
                __writeCfg(SETTINGS, settings)
                return
            end
        end
        io.stderr:write("spm-error: Repository '"..repositoryUrl.."' not found")
    end
end

local function listRepositories()
    local settings = __readCfg(SETTINGS, nil)
    if settings then
        for i,v in ipairs(settings["repos"]) do
            print(i..". "..v)
        end
    end
end

local function searchPackage(packageName)
    local settings = __readCfg(SETTINGS, nil)
    if settings then
        local found = false
        for i,r in ipairs(settings["repos"]) do
            local content = __tryFindRepo(r, packageName)
            if content then
                found = true
                if packageName == nil then
                    for k,f in pairs(content) do
                        print(k)
                    end
                else
                    print("spm: '"..packageName.."' found in repository '"..r.."'")
                    return
                end
            end
        end
        if not found then
            if packageName == nil then
                print("spm: No packages found")
            else
                print("spm: No packages found with name '"..packageName.."'")
            end
        end
    end
end

local function queryPackage(packageName)
    local settings = __readCfg(SETTINGS, nil)
    if settings then
        local found = false
        local content = __tryFindFile(packageName, settings)
        if content then
            found = true
            if packageName == nil then
                for n,f in pairs(content) do
                    print(n)
                end
            else
                print("spm: '"..packageName.."' found, files:")
                for i = 1, #content["files"], 1 do
                    print(content["files"][i])
                end
                return
            end
        end
        if not found then 
            if packageName == nil then
                print("spm: No packages installed")
            else
                print("spm: No packages installed with name '"..packageName.."'")
            end
        end
    end
end

local function installPackage(packageName, force, reboot)
    -- Find and install package and it's dependencies
    local settings = __readCfg(SETTINGS, nil)
    if settings then
        local success = __getPack(packageName, settings, force, false)
        if success then
            __writeCfg(SETTINGS, settings)
            if reboot then
                print("spm: Rebooting...")
                os.sleep(1)
                os.execute("reboot")
            end
        end
    end
end

local function removePackage(packageName, force)
    -- Find and remove package and it's dependencies
    local settings = __readCfg(SETTINGS, nil)
    if settings then
        local success = __deletePack(packageName, settings, force, false)
        if success then
            __writeCfg(SETTINGS, settings)
            return
        end
    end
end

local function updatePackage(packageName, reboot)
    -- Uninstall and re-download (ignores dependencies)
    local settings = __readCfg(SETTINGS, nil)
    if settings then
        local package = __tryFindFile(packageName, settings)
        if package then
            if packageName == nil then
                print("spm: Updating all packages...")
                for k,v in pairs(package) do
                    local success = __deletePack(k, settings, false, true)
                    if success then
                        success = __getPack(k, settings, true, true)
                    end
                end
                __writeCfg(SETTINGS, settings)
                print("spm: Updating packages succesful")
                if reboot then
                    print("spm: Rebooting...")
                    os.sleep(1)
                    os.execute("reboot")
                end
            else
                print("spm: Updating package '"..packageName.."'...")
                local success = __deletePack(packageName, settings, false, true)
                if success then
                    success = __getPack(packageName, settings, true, true)
                end
                __writeCfg(SETTINGS, settings)
                print("spm: Updating package '"..packageName.."' succesful")
                if reboot then
                    print("spm: Rebooting...")
                    os.sleep(1)
                    os.execute("reboot")
                end
            end
        else
            if packageName == nil then
                io.stderr:write("spm-error: No packages found")
            else
                io.stderr:write("spm-error: No packages found with name '"..packageName.."'")
            end
        end
    end
end

local args, options = shell.parse(...)
if args[1] == "addrepo" then
    if args[2] == nil then
        printUsage()
        return
    end
    addRepository(args[2])
elseif args[1] == "removerepo" then
    if args[2] == nil then
        printUsage()
        return
    end
    removeRepository(args[2])
elseif args[1] == "listrepo" then
    listRepositories()
elseif args[1] == "search" then
    searchPackage(args[2])
elseif args[1] == "query" then
    queryPackage(args[2])
elseif args[1] == "update" then
    updatePackage(args[2], options["r"])
elseif args[1] == "install" then
    if args[2] == nil then
        printUsage()
        return
    end
    installPackage(args[2], options["f"], options["r"])
elseif args[1] == "remove" then
    if args[2] == nil then
        printUsage()
        return
    end
    removePackage(args[2], options["f"])
else
    printUsage()
    return
end