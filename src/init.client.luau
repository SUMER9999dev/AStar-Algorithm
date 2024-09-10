-- Simple A* implementation created by sumer_real for HiddenDevs verification


local collectionService = game:GetService('CollectionService')
local players = game:GetService('Players')
local runService = game:GetService('RunService')


local TARGET_NAME = 'TargetCell'
local CELL_TAG = 'Cell'
local NAVIGATOR_TRACE_TAG = 'Trace'


--[[
this is cell interface, it will be used in grid
]]
type Cell = {
	x: number,
	y: number,

	neighbors: {Cell},

	distanceTo: (self: Cell, Cell) -> number,
	distanceToPoint: (self: Cell, x: number, y: number) -> number,
	isNeighbor: (self: Cell, Cell) -> boolean
}


--[[
grid is a set of cells, so it also finds and sets the neighbors of the cells
]]
type Grid = {
	cells: {Cell},

	isIn: (self: Grid, Cell) -> boolean,
	findCellAtPoint: (self: Grid, x: number, y: number) -> Cell?
}


-- Cell implementation
local Cell = {}
Cell.__index = Cell

function Cell.new(x: number, y: number)
	local self = {}

	self.x = x
	self.y = y

	self.neighbors = {}

	return (setmetatable(self, Cell) :: any) :: Cell
end

function Cell:distanceTo(distination: Cell)
	return self:distanceToPoint(distination.x, distination.y)
end

function Cell:distanceToPoint(x: number, y: number)
	return math.sqrt((self.x - x) ^ 2 + (self.y - y) ^ 2)
end

function Cell:isNeighbor(cell: Cell)
	if self == cell then  -- yourself is not neighbor of yourself
		return false
	end

	if (self.x - 1) == cell.x and self.y == cell.y then  -- will check left neighbor
		return true
	end

	if (self.x + 1) == cell.x and self.y == cell.y then  -- will check right neighbor
		return true
	end

	if self.x == cell.x and (self.y - 1) == cell.y then  -- will check lower neighbor
		return true
	end

	if self.x == cell.x and (self.y + 1) == cell.y then  -- will check upper neighbor
		return true
	end

	if (self.x - 1) == cell.x and (self.y + 1) == cell.y then  -- will check left-upper neighbor
		return true
	end

	if (self.x + 1) == cell.x and (self.y + 1) == cell.y then  -- will check right-upper neighbor
		return true
	end

	if (self.x + 1) == cell.x and (self.y - 1) == cell.y then  -- will check right-lower neighbor
		return true
	end

	if (self.x - 1) == cell.x and (self.y + 1) == cell.y then  -- will check left-lower neighbor
		return true
	end

	return false
end

function Cell.__eq(self: Cell, another: Cell)
	if typeof(another) ~= 'table' then
		return false
	end

	return self.x == another.x and self.y == another.y
end


local Grid = {}
Grid.__index = Grid

function Grid.new(cells: {Cell})
	local self = {}

	self.cells = cells

	if not table.isfrozen(self.cells) then  -- check that cells table is not frozen, because table.freeze will error if table is already frozen
		table.freeze(self.cells)  -- we need to freeze cells, because i don't want to findNeighbors each cells update
	end

	local grid = setmetatable(self, Grid)

	grid:__findNeighbors()

	return grid :: Grid
end

--[[
in A* algorithm we need to check neighbors of cells, so we will do that on Grid creation
]]
function Grid:__findNeighbors()
	for _, cell in self.cells do
		for _, another_cell in self.cells do
			if cell:isNeighbor(another_cell) then
				table.insert(cell.neighbors, another_cell)
			end
		end
	end
end

function Grid:findCellAtPoint(x: number, y: number)
	for _, cell in self.cells do
		if cell.x == x and cell.y == y then
			return cell
		end
	end

	return nil
end

function Grid:isIn(cell: Cell)
	return table.find(self.cells, cell) ~= nil
end


--[[
A* algorithm it self

returns two things:

boolean - is target reached
table of cells - path to target
]]
local function aStar(grid: Grid, start: Cell, target: Cell, isBlocked: (Cell) -> boolean): (boolean, {Cell})
	if not grid:isIn(start) then  -- start is not in grid, so target is not reachable
		return false, {}
	end

	if not grid:isIn(target) then  -- target is not in grid, so it's not reachable
		return false, {}
	end

	if isBlocked(start) then  -- start is blocked, so target not reachable
		return false, {}
	end

	if isBlocked(target) then  -- we can't reach blocked cell
		return false, {}
	end

	if start == target then  -- already reached target!
		return true, {}
	end

	local gScore = 0  -- accumulated path cost

	local closed = {} :: {[Cell]: boolean}  -- there will be stored all cells that we checked
	local path = {start} :: {Cell}  -- there will be stored our path

	for _, cell in path do
		if closed[cell] then  -- skip already checked cell
			continue
		end

		if cell == target then
			break
		end

		local bestNeighbor = nil
		local bestNeighborScore = 0

		for _, neighbor in cell.neighbors do  -- here we need to find neighbor with lowest path cost
			if closed[neighbor] then
				continue
			end

			if isBlocked(neighbor) then
				continue
			end

			if neighbor == target then  -- end neighbor search if we can jump directly to neighbor
				bestNeighbor = neighbor
				bestNeighborScore = gScore  -- we don't need to add path cost, if it's end of path
				break
			end

			local fScore = gScore + target:distanceTo(neighbor)

			if bestNeighbor == nil or bestNeighborScore > fScore then
				bestNeighbor = neighbor
				bestNeighborScore = fScore
			end
		end

		gScore = bestNeighborScore
		table.insert(path, bestNeighbor)
		closed[cell] = true  -- mark that we checked this cell
	end

	if path[#path] ~= target then  -- check if last path cell is not target, that means we not reached target
		return false, {}
	end

	return true, path
end


local cells = {} :: {Cell}
local blockedCells = {} :: {[Cell]: boolean}
local cellToPart = {} :: {[Cell]: CellPart}  -- need to get part from cell
local partToCell = {} :: {[CellPart]: Cell}  -- need to get cell from part


--[[
	we need to destroy previous traces before tracing new path
]]
local function cleanupNavigatorTrace()
	for _, trace in collectionService:GetTagged(NAVIGATOR_TRACE_TAG) do
		trace:Destroy()
	end
end


--[[
simply creates beam from "from cell" to "to cell"
]]
local function trace(from: Cell, to: Cell)
	local fromPart = cellToPart[from]
	local toPart = cellToPart[to]

	local beam = Instance.new('Beam')

	beam.Parent = fromPart
	beam.Attachment0 = fromPart.Attachment
	beam.Attachment1 = toPart.Attachment
	beam.Color = ColorSequence.new(Color3.fromRGB(94, 242, 131))
	beam.FaceCamera = true

	beam:AddTag(NAVIGATOR_TRACE_TAG)
end


--[[
navigates from start cell to target cell and uses trace to visualize path
]]
local function navigateFromCell(grid: Grid, cell: Cell)
	local target = workspace:FindFirstChild(TARGET_NAME)

	if not target then
		return
	end

	cleanupNavigatorTrace()

	local isReachable, path = aStar(grid, cell, partToCell[target], function(cell)
		return blockedCells[cell] ~= nil
	end)

	if not isReachable then
		return
	end

	for index, cellInPath in path do
		local nextCell = path[index + 1]
		
		if not nextCell then
			continue
		end

		trace(cellInPath, nextCell)
	end
end


--[[
helper function to navigate character to target cell using A* algorithm
that function will return cleanup function
]]
local function navigateCharacterToTarget(character: Model?, grid: Grid): () -> ()
	if not character then
		return function()
			cleanupNavigatorTrace()
		end
	end

	local navigationConnection: RBXScriptConnection? = nil
	local primaryPart = character.PrimaryPart

	if not primaryPart then
		return function()
			cleanupNavigatorTrace()
		end
	end

	local currentCell = nil :: Cell?

	navigationConnection = runService.RenderStepped:Connect(function()
		--[[
		we need to use RenderStepped instead of GetPropertyChangedSignal,
		because roblox didn't fires it on character movement
		]]

		local position = primaryPart:GetPivot().Position
		local characterCellPosition = Vector2.new(math.round(position.X / 16), math.round(position.Z / 16))  -- here we need to use Z instead of Y, because we in 3D space. Also we use math.round instead of // (floor devided) because there can be negative values, -16.0123 // 16 == 2

		if not currentCell then
			local cell = grid:findCellAtPoint(characterCellPosition.X, characterCellPosition.Y)

			if not cell then
				return
			end

			currentCell = cell
			navigateFromCell(grid, currentCell)
			return
		end

		if currentCell.x == characterCellPosition.X and currentCell.y == characterCellPosition.Y then  -- don't try to update current cell if player stay in same cell
			return
		end

		local cell = grid:findCellAtPoint(characterCellPosition.X, characterCellPosition.Y)

		if not cell then
			return
		end

		currentCell = cell
		navigateFromCell(grid, currentCell)
	end)

	return function()
		if navigationConnection then
			navigationConnection:Disconnect()
		end

		cleanupNavigatorTrace()
	end
end


if not game:IsLoaded() then  -- firstly we need to wait game to load
	game.Loaded:Wait()
end


type CellPart = BasePart & {Attachment: Attachment}
local partCells = collectionService:GetTagged(CELL_TAG) :: {CellPart}
local navigateCleanup = nil :: (() -> ())?


for index, cellPart in partCells do
	local isBlocked = cellPart:GetAttribute('IsBlocked') :: boolean
	local cell = Cell.new(cellPart.Position.X // 16, cellPart.Position.Z // 16)  -- position need to be floor divided by 16, because 16 is cell size. so we get normalized position (16, 16) -> (1, 1)

	if isBlocked then
		blockedCells[cell] = true
	end
 
	cellToPart[cell] = cellPart
	partToCell[cellPart] = cell
	table.insert(cells, cell)
end


local grid = Grid.new(cells)


navigateCleanup = navigateCharacterToTarget(players.LocalPlayer.Character, grid)

players.LocalPlayer.CharacterRemoving:Connect(function()
	if navigateCleanup then
		navigateCleanup()
	end
end)

players.LocalPlayer.CharacterAdded:Connect(function(character)
	navigateCleanup = navigateCharacterToTarget(character, grid)
end)
