local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replica = require(ReplicatedStorage.Packages.Replica)

local module = {}

export type Path = { string | number }

module.Template = {
    Snowflakes = 0,
    Wins = 0,
    Eliminations = 0,
}

module.Token = Replica.Token("PlayerStore")

function module.getContainer<T>(tbl: T, path: Path): T | { any }
    local container = tbl
    for _, arg in pairs(path) do
        if not container[arg] then
            error(`No index "{arg}" in: `, container)
        end

        if type(container[arg]) ~= "table" then
            break
        end

        container = container[arg]
    end

    return container
end

return module