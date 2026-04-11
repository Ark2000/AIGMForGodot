-- Master test runner
package.path = package.path .. ";./?.lua"

local phases = {
    "test/phases/phase1_test",
    "test/phases/phase2_test",
    "test/phases/phase3_test",
    "test/phases/phase4_test",
    "test/phases/phase5_test",
    "test/phases/phase6_test",
}

local all_passed = true

for _, phase in ipairs(phases) do
    -- clear module cache so each phase starts fresh
    local to_clear = {}
    for k in pairs(package.loaded) do
        if not k:match("^_") then
            table.insert(to_clear, k)
        end
    end
    for _, k in ipairs(to_clear) do
        package.loaded[k] = nil
    end

    print("\n" .. string.rep("═", 50))
    local ok, err = pcall(require, phase)
    if not ok then
        print("ERROR in " .. phase .. ": " .. tostring(err))
        all_passed = false
    end
end

print("\n" .. string.rep("═", 50))
if all_passed then
    print("All phases completed.")
else
    print("Some phases had errors.")
    os.exit(1)
end
