local arrayUtils = {}

---@param arr any[]
---@param val any
---@return boolean
arrayUtils.arrayHasValue = function(arr, val)
    for _, v in pairs(arr) do
        if v == val then
            return true
        end
    end

    return false
end

---@param arr any[]
---@param val any
arrayUtils.addUnique = function(arr, val)
    if not arrayUtils.arrayHasValue(arr, val) then
        table.insert(arr, val)
    end
end

---@param arr any[]
---@param func function(any): any
---@return any[]
arrayUtils.map = function(arr, func)
    if type(arr) ~= 'table' then return {} end

    local results = {}
    for i = 1, #arr do
        table.insert(results, func(arr[i]))
    end
    return results
end

---@param tab table
---@param fields2Omit string[]
---@param isTryUserdata? boolean
---@return table
arrayUtils.cloneDeepOmittingFields = function(tab, fields2Omit, isTryUserdata)
    local results = {}
    if type(tab) ~= 'table' and not(isTryUserdata and type(tab) == 'userdata') then return results end

    if type(fields2Omit) ~= 'table' then fields2Omit = {} end

    for key, value in pairs(tab) do
        if not arrayUtils.arrayHasValue(fields2Omit, key) then
            if type(value) == 'table' or (isTryUserdata and type(value) == 'userdata') then
                results[key] = arrayUtils.cloneDeepOmittingFields(value, fields2Omit, isTryUserdata)
            else
                results[key] = value
            end
        end
    end
    return results
end

---@param tab table
---@param fields2Omit string[]
---@param isTryUserdata? boolean
---@return table
arrayUtils.cloneOmittingFields = function(tab, fields2Omit, isTryUserdata)
    local results = {}
    if type(tab) ~= 'table' and not(isTryUserdata and type(tab) == 'userdata') then return results end

    if type(fields2Omit) ~= 'table' then fields2Omit = {} end

    for key, value in pairs(tab) do
        if not arrayUtils.arrayHasValue(fields2Omit, key) then
            results[key] = value
        end
    end
    return results
end

---@param arr1 any[] --gets altered in place
---@param arr2 any[]
arrayUtils.concatValues = function(arr1, arr2)
    if type(arr1) ~= 'table' or type(arr2) ~= 'table' then
        return
    end

    for _, v2 in pairs(arr2) do
        table.insert(arr1, v2)
    end
end

---@param arr1 string[]|number[]
---@param arr2 string[]|number[]
---@return any[]
arrayUtils.getUniqueConcatValues = function(arr1, arr2)
    if type(arr1) ~= 'table' or type(arr2) ~= 'table' then
        return {}
    end
    local table1_indexed, table2_indexed = {}, {}
    for _, value in pairs(arr1) do
        table1_indexed[value] = true
    end
    for _, value in pairs(arr2) do
        table2_indexed[value] = true
    end
    for key2, _ in pairs(table2_indexed) do
        table1_indexed[key2] = true
    end
    local results = {}
    for key, _ in pairs(table1_indexed) do
        results[#results+1] = key
    end
    return results
end

---@param table1 table --gets altered in place
---@param table2 table
arrayUtils.concatKeysValues = function(table1, table2)
    if type(table1) ~= 'table' or type(table2) ~= 'table' then
        return
    end

    for k2, v2 in pairs(table2) do
        table1[k2] = v2
    end
end

---@param arr any[]
---@return nil|any
arrayUtils.getFirst = function(arr)
    if arr == nil or #arr == nil then return nil end

    return arr[1]
end

---@param arr any[]
---@return nil|any
arrayUtils.getLast = function(arr)
    if arr == nil or #arr == nil then return nil end

    return arr[#arr]
end

---@param tab table|any[]
---@param elementName? string
---@param asc? boolean
---@return table|any[]
arrayUtils.sort = function(tab, elementName, asc)
    if type(tab) ~= 'table' then
        return tab
    end

    if type(asc) ~= 'boolean' then
        asc = true
    end

    if type(elementName) == 'string' then
        table.sort(
            tab,
            function(elem1, elem2)
                if not elem1 or not elem2 or not (elem1[elementName]) or not (elem2[elementName]) then
                    return true
                end
                if asc then
                    return elem1[elementName] < elem2[elementName]
                end
                return elem1[elementName] > elem2[elementName]
            end
        )
    else
        table.sort(
            tab,
            function(elem1, elem2)
                if not elem1 or not elem2 or not (elem1) or not (elem2) then
                    return true
                end
                if asc then
                    return elem1 < elem2
                end
                return elem1 > elem2
            end
        )
    end

    return tab
end

---@param tab table|any[]
---@param isDiscardNil? boolean
---@return integer
arrayUtils.getCount = function(tab, isDiscardNil)
    if type(tab) ~= 'table' and type(tab) ~= 'userdata' then
        return -1
    end

    local result = 0
    for _, value in pairs(tab) do
        if not(isDiscardNil) or value ~= nil then
            result = result + 1
        end
    end

    return result
end

---@param tab table|any[]
---@param isIgnoreNil? boolean
---@return boolean
arrayUtils.tableHasValues = function(tab, isIgnoreNil)
    if type(tab) ~= 'table' and type(tab) ~= 'userdata' then
        return false
    end

    local result = 0
    for _, value in pairs(tab) do
        if not(isIgnoreNil) or value ~= nil then
            return true
        end
    end

    return false
end

---@param tab table|any[]
---@param fieldName? string
---@param fieldValueNonNil any
---@return integer
arrayUtils.findIndex = function(tab, fieldName, fieldValueNonNil)
    if type(tab) ~= 'table' or fieldValueNonNil == nil then return -1 end

    if type(fieldName) == 'string' then
        if string.len(fieldName) > 0 then
            for key, value in pairs(tab) do
                if type(value) == 'table' and value[fieldName] == fieldValueNonNil then
                    -- print('LOLLO findIndex found index =', i, 'tab[i][fieldName] =', tab[i][fieldName], 'fieldValueNonNil =', fieldValueNonNil, 'content =')
                    -- debugPrint(tab[i])
                    return key
                end
            end
        end
    else
        for key, value in pairs(tab) do
            if value == fieldValueNonNil then
                return key
            end
        end
    end

    return -1
end

---@param tab any[]
---@return any[]
arrayUtils.getReversed = function(tab)
    if type(tab) ~= 'table' then return tab end

    local reversedTab = {}
    for i = #tab, 1, -1 do
        reversedTab[#reversedTab+1] = tab[i]
    end

    return reversedTab
end

return arrayUtils
