local log = require "telescope.log"

local LinkedList = require "telescope.algos.linked_list"

local EntryManager = {}
EntryManager.__index = EntryManager

function EntryManager:new(max_results)
  return setmetatable({
    dirty = true,
    linked_states = LinkedList:new { track_at = max_results },
    max_results = max_results,
    worst_acceptable_score = math.huge,
  }, self)
end

function EntryManager:num_results()
  return self.linked_states.size
end

function EntryManager:get_container(index)
  local count = 0
  for val in self.linked_states:iter() do
    count = count + 1

    if count == index then
      return val
    end
  end

  return {}
end

function EntryManager:get_entry(index)
  return self:get_container(index)[1]
end

function EntryManager:get_score(index)
  return self:get_container(index)[2]
end

function EntryManager:get_ordinal(index)
  return self:get_entry(index).ordinal
end

function EntryManager:find_entry(entry)
  local count = 0
  for container in self.linked_states:iter() do
    count = count + 1

    if container[1] == entry then
      return count
    end
  end

  return nil
end

function EntryManager:_update_score_from_tracked()
  local linked = self.linked_states

  if linked.tracked then
    self.worst_acceptable_score = math.min(self.worst_acceptable_score, linked.tracked[2])
  end
end

function EntryManager:_insert_container_before(picker, index, linked_node, new_container)
  self.linked_states:place_before(index, linked_node, new_container)

  self:_update_score_from_tracked()
end

function EntryManager:_insert_container_after(picker, index, linked_node, new_container)
  self.linked_states:place_after(index, linked_node, new_container)

  self:_update_score_from_tracked()
end

function EntryManager:_append_container(picker, new_container, should_update)
  self.linked_states:append(new_container)
  self.worst_acceptable_score = math.min(self.worst_acceptable_score, new_container[2])
end

function EntryManager:add_entry(picker, score, entry, prompt)
  score = score or 0

  local max_res = self.max_results
  local worst_score = self.worst_acceptable_score
  local size = self.linked_states.size

  local new_container = { entry, score }

  -- Short circuit for bad scores -- they never need to be displayed.
  --    Just save them and we'll deal with them later.
  if score >= worst_score then
    return self.linked_states:append(new_container)
  end

  self.dirty = true

  -- Short circuit for first entry.
  if size == 0 then
    self.linked_states:prepend(new_container)
    return
  end

  for index, container, node in self.linked_states:ipairs() do
    if container[2] > score then
      return self:_insert_container_before(picker, index, node, new_container)
    end

    if score < 1 and container[2] == score and picker.tiebreak(entry, container[1], prompt) then
      return self:_insert_container_before(picker, index, node, new_container)
    end

    -- Don't add results that are too bad.
    if index >= max_res then
      return self:_append_container(picker, new_container, false)
    end
  end

  if self.linked_states.size >= max_res then
    self.worst_acceptable_score = math.min(self.worst_acceptable_score, score)
  end

  return self:_insert_container_after(picker, size + 1, self.linked_states.tail, new_container)
end

function EntryManager:iter()
  local iterator = self.linked_states:iter()
  return function()
    local val = iterator()
    if val then
      return val[1]
    end
  end
end

function EntryManager:window(start, finish)
  local results = {}

  local idx = 0
  for val in self.linked_states:iter() do
    idx = idx + 1

    if idx >= start then
      table.insert(results, val[1])
    end

    if idx >= finish or idx >= self.max_results then
      break
    end
  end

  return results
end

return EntryManager
