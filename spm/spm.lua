---------------------------------------------------
-- SIMPLE PACKAGE MANAGER (SPM)
-- Register Git repositories, search, install, update and remove packages
-- -ar, -addrepo [url] = Add repository
-- -rr, -removerepo [url] = Remove repository
-- -s, -search [?packageName?] = List all packages from repositories, or search a package
-- -u, -update [?packageName?] = Update all packages (or optionally a package)
-- -i, -install [packageName] = Install package
-- -r, -remove [packageName] = Remove package
---------------------------------------------------

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

local PACKAGES_F = "packages.cfg"
local SETTINGS = "/etc/spm.cfg"

local function printUsage()
    print("Simple Package Manager (spm) \n")
    print("List of commands and parameters (<> = required, [] = optional):")
    print("addrepo <url> = Add repository")
    print("removerepo <url> = Remove repository")
    print("listrepo = List all repositories")
    print("search [packageName] = List all packages from repositories, or search a package")
    print("query [packageName] = List all installed packages, or query for an installed package")
    print("update [packageName] = Update everything or the given package")
    print("install [-f] <packageName> = Install package (-f forces the installation)")
    print("remove <packageName> = Remove package")
end

local function __concatUrl(url, file)
    if file[1] == '/' then
        return text.trim(url..file)
    else
        return text.trim(url.."/"..file)
    end
end

local function __getContent(url)
    local result, response = pcall(internet.request, url)
    if result then
        local content = ""
        for chunk in response do
            content = content..chunk
        end
        return serialization.unserialize(content)
    end
    return nil
end

local function __downloadFile(url, path)
    -- Auto-force because why not
    return wget("-fq",url,path)
end

local function __readCfg(filepath)
    local file, emsg = io.open(filepath, "rb")
    if not file then
        io.stderr:write("spm-error: Cannot read file at path " .. filepath .. ": " .. emsg)
        return nil
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
    local success, content = pcall(__getContent(url))
    if success then
        if packageName == nil then
            return content
        end
        for k,p in pairs(content) do
            if k == packageName then
                return p
            end
        end
    end
    return nil
end

local function __tryFindFile(packageName)
    local settings = __readCfg(SETTINGS)
    if settings then
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

local function addRepository(repositoryUrl)
    -- Look for packages.cfg in given url, if found write it to settings
    local url = __concatUrl(repositoryUrl, PACKAGES_F)
    print(url)
    local success, content = pcall(__getContent(url))
    if content then
        local settings = __readCfg(SETTINGS) or {}
        if settings then
            for i,v in ipairs(settings["repos"]) do
                if repositoryUrl == v then
                    print("spm: Repository '"..repositoryUrl.."' already exists")
                    return
                end
            end
        else
            settings["repos"] = {}
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
    local settings = __readCfg(SETTINGS)
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
    local settings = __readCfg(SETTINGS)
    if settings then
        for i,v in ipairs(settings["repos"]) do
            print(i..". "..v)
        end
    end
end

local function searchPackage(packageName)
    local settings = __readCfg(SETTINGS)
    if settings then
        local found = false
        for i,r in ipairs(settings["repos"]) do
            local content = __tryFindRepo(r, packageName)
            if content then
                found = true
                if packageName == nil or packageName == "" then
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
            print("spm: No packages found with name '"..packageName.."'")
        end
    end
end

local function queryPackage(packageName)
    local settings = __readCfg(SETTINGS)
    if settings then
        local found = false
        for k,p in pairs(settings["packages"]) do
            local content = __tryFindFile(packageName)
            if content then
                found = true
                if packageName == nil or packageName == "" then
                    for k,f in pairs(content) do
                        print(k)
                    end
                else
                    print("spm: '"..packageName.."' found, files:")
                    for i,v in ipairs(content) do
                        print(v)
                    end
                    return
                end
            end
        end
        if not found then 
            print("spm: No packages found with name '"..packageName.."'")
        end
    end
end

local function installPackage(packageName, force)
    -- Look for packageName in repositories, if found install to hard drive and write to installed packages
    local settings = __readCfg(SETTINGS)
    if settings then
        local package = __tryFindFile(packageName)
        if package and not force then
            print("spm: Package '"..packageName.."' already installed")
            return
        end
        for i,repo in ipairs(settings["repos"]) do
            package = __tryFindRepo(repo, packageName)
            if package then
                print("spm: Installing '"..packageName.."'...")
                settings["packages"][packageName] = {}
                for dpath,installDir in pairs(package.files) do
                    local rpath = __concatUrl(repo,dpath)
                    local filename = fs.name(dpath)
                    local filepath = fs.concat(installDir, filename)
                    local success, response = pcall(__downloadFile(rpath, filepath))
                    if success and response then
                        table.insert(settings["packages"][packageName].files, filepath)
                        print("spm: "..rpath.." copied to "..filepath)
                    else
                        io.stderr:write("spm-error: Error installing '"..packageName.."': "..response)
                        return
                    end
                end
                __writeCfg(SETTINGS, settings)
                print("spm: Package '"..packageName.."' installed succesfully.")
                return
            end
        end
        io.stderr:write("spm-error: No packages found with name '"..packageName.."'")
        return
    end
end

local function removePackage(packageName)
    -- Look for packageName in installed packages, if found remove it from the hard drive and the settings
    local settings = __readCfg(SETTINGS)
    if settings then
        local package = __tryFindFile(packageName)
        if package then
            for i,v in ipairs(package.files) do
                fs.remove(v)
            end
            settings["packages"][packageName] = nil
            __writeCfg(SETTINGS, settings)
            print("spm: Package '"..packageName"' removed")
            return
        end
        io.stderr:write("spm-error: No packages found with name '"..packageName.."'")
    end
end

local function updatePackage(packageName)
    -- Uninstall and re-download
    local settings = __readCfg(SETTINGS)
    if settings then
        local package = __tryFindFile(packageName)
        if package then
            if packageName == nil or packageName == "" then
                for k,v in pairs(package) do
                    removePackage(k)
                    installPackage(k)
                end
            else

            end
        end
        if packageName == nil or packageName == "" then
            -- Update all installed packages
            print("spm: Updating all packages...")
            for name,p in pairs(settings["packages"]) do
                removePackage(name)
                installPackage(name)
            end
        else
            -- Update package
            local package = __tryFindFile(packageName)
            if package then
                print("spm: Updating package '"..packageName.."'...")
                removePackage(packageName)
                installPackage(packageName)
                return
            end
            io.stderr:write("spm-error: No packages found with name '"..packageName.."'")
        end
    end
end

local args, options = shell.parse(...)
if args[1] == "addrepo" then
    if args[2] == nil then
        printUsage()
        return
    end
    addRepository(text.trim(args[2]))
elseif args[1] == "removerepo" then
    if args[2] == nil then
        printUsage()
        return
    end
    removeRepository(text.trim(args[2]))
elseif args[1] == "listrepo" then
    listRepositories()
elseif args[1] == "search" then
    searchPackage(text.trim(args[2]))
elseif args[1] == "query" then
    queryPackage(text.trim(args[2]))
elseif args[1] == "update" then
    updatePackage(text.trim(args[2]))
elseif args[1] == "install" then
    if args[2] == nil then
        printUsage()
        return
    end
    installPackage(text.trim(args[2]), options["f"])
elseif args[1] == "remove" then
    if args[2] == nil then
        printUsage()
        return
    end
    removePackage(text.trim(args[2]))
else
    printUsage()
    return
end