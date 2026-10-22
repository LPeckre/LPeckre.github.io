--[[
  publications.lua — builds the publication list from one or more BibTeX files.

  Front matter of publications.qmd:
    publications-bib: [Mes_Publications.bib, publications-extra.bib]
    highlight-author: Peckre                 (family name shown in bold)
    equal-contribution: {"10.xxx/yyy": "1,2"}  (authors 1 and 2 get an asterisk)
    keep-case: [Madagascar]                  (words never lowercased in titles)
  and placeholders  ::: {#publication-list} :::  (the list) and
  ::: {#publication-stats} :::  (number of publications / first-authored).

  In a .bib entry, note = {equal: 1,2} also works; "and others" -> "et al."
]]

local bibfiles = { "publications.bib" }
local equal_by_doi = {}
local highlight = "Peckre"
local MAX_AUTHORS = 15   -- longer lists: first 3 authors, highlighted author, "et al."

local function str(x)
  if x == nil then return "" end
  return pandoc.utils.stringify(x)
end

-- "Louise R." -> "L.R."   "Anne-Claire" -> "A.-C."
local function initials(given)
  local out = {}
  for word in given:gmatch("%S+") do
    local parts = {}
    for part in word:gmatch("[^%-]+") do
      local first = part:match("^[%z\1-\127\194-\244][\128-\191]*")
      if first and first ~= "." then table.insert(parts, first:upper() .. ".") end
    end
    table.insert(out, table.concat(parts, "-"))
  end
  return table.concat(out, "")
end

local function year_of(ref)
  return str(ref.issued):match("%d%d%d%d") or "n.d."
end

local function equal_positions(ref)
  local set = {}
  local note = str(ref.note)
  local list = note:match("equal:%s*([%d,%s]+)")
  local doi = str(ref.DOI or ref.doi):lower()
  if not list and equal_by_doi[doi] then list = equal_by_doi[doi] end
  if list then
    for n in list:gmatch("%d+") do set[tonumber(n)] = true end
  end
  return set
end

local function format_name(a, pos, eq)
  local name
  if a.family then
    local ini = initials(str(a.given))
    name = str(a.family) .. (ini ~= "" and (" " .. ini) or "")
  else
    name = str(a.literal)
  end
  if eq[pos] then name = name .. "*" end
  if str(a.family) == highlight then return pandoc.Strong(pandoc.Str(name)) end
  return pandoc.Str(name)
end

local function author_inlines(ref)
  local authors = ref.author or {}
  local eq = equal_positions(ref)
  local n = #authors
  local has_others = n > 0 and str(authors[n].literal) == "others"
  if has_others then n = n - 1 end

  local inl = pandoc.Inlines{}
  if n > MAX_AUTHORS then
    -- long list: first 3 authors, then the highlighted author if further down, then "et al."
    local hl
    for i = 1, n do if str(authors[i].family) == highlight then hl = i end end
    for i = 1, 3 do
      if i > 1 then inl:extend{pandoc.Str(","), pandoc.Space()} end
      inl:insert(format_name(authors[i], i, eq))
    end
    if hl and hl > 3 then
      inl:extend{pandoc.Str(","), pandoc.Space(), pandoc.Str("…,"), pandoc.Space(),
                 format_name(authors[hl], hl, eq), pandoc.Str(","), pandoc.Space(), pandoc.Str("…")}
    end
    inl:extend{pandoc.Space(), pandoc.Str("et al.")}
    return inl
  end

  for i = 1, n do
    if i > 1 then
      if i == n and not has_others then
        inl:extend{pandoc.Space(), pandoc.Str("&"), pandoc.Space()}
      else
        inl:extend{pandoc.Str(","), pandoc.Space()}
      end
    end
    inl:insert(format_name(authors[i], i, eq))
  end
  if has_others then inl:extend{pandoc.Space(), pandoc.Str("et al.")} end
  return inl
end

-- Sentence case for titles. Pandoc already lowercases most words, but Zotero
-- protects some with braces ({{Clutch Investment}}) and capitalises the word
-- after a colon. Rules: keep the first word and words after ? ! . ; keep
-- acronyms (GPS, GAMMs); in italics keep the genus, lowercase the species.
-- Words listed in "keep-case" (front matter) are never lowercased.
local keep_case = {}

local function is_titlecase(w)
  if w:match("%d") then return false end
  local core = w:gsub("^[%p]+", ""):gsub("[%p]+$", "")
  if not core:match("^%u") then return false end
  -- no other capital letters, except right after a hyphen (Self-Medication)
  local rest = core:sub(2):gsub("%-%u", "-x")
  return not rest:match("%u")
end

local function lower_word(w)
  local core = w:gsub("[%p]+$", ""):gsub("^[%p]+", "")
  if keep_case[core] then return w end
  return (w:gsub("(%f[%w]%u)", function(c) return c:lower() end))
end

local function sentence_case(title)
  local st = { first = true, cap_next = false, prev_emph = false }
  local function walk(list, emph)
    local out = pandoc.Inlines{}
    for _, el in ipairs(list) do
      if el.t == "Str" then
        local w = el.text
        if not emph then st.prev_emph = false end
        if st.first or st.cap_next then
          -- keep as is
        elseif emph and not st.prev_emph then
          -- genus: keep capital
        elseif is_titlecase(w) then
          w = lower_word(w)
        end
        st.first = false
        st.cap_next = w:match("[%?!%.]$") ~= nil
        st.prev_emph = emph or false
        out:insert(pandoc.Str(w))
      elseif el.t == "Space" then
        out:insert(el)
      elseif el.t == "Emph" then
        out:insert(pandoc.Emph(walk(el.content, true)))
      elseif el.t == "Span" then
        out:insert(pandoc.Span(walk(el.content, emph), el.attr))
      elseif el.t == "Quoted" then
        out:insert(pandoc.Quoted(el.quotetype, walk(el.content, emph)))
      elseif el.content then
        el.content = walk(el.content, emph); out:insert(el)
      else
        out:insert(el)
      end
      if el.t ~= "Str" and el.t ~= "Space" and el.t ~= "Emph" and el.t ~= "Span" then st.prev_emph = false end
    end
    return out
  end
  return walk(pandoc.Inlines(title), false)
end

local function entry_para(ref)
  local inl = author_inlines(ref)
  inl:extend{pandoc.Space(), pandoc.Str("(" .. year_of(ref) .. ")"), pandoc.Space()}
  if ref.title then
    inl:extend(sentence_case(ref.title))
    if not str(ref.title):match("[%.%?!]$") then inl:insert(pandoc.Str(".")) end
  end

  local venue = ref["container-title"]
  if ref.type == "thesis" then
    inl:extend{pandoc.Space(), pandoc.Emph(pandoc.Str("Ph.D. dissertation"))}
    if ref.publisher then
      inl:extend{pandoc.Str(","), pandoc.Space()}
      inl:extend(ref.publisher)
    end
    inl:insert(pandoc.Str("."))
  elseif venue then
    inl:insert(pandoc.Space())
    inl:insert(pandoc.Emph(venue))
    if ref.volume then inl:extend{pandoc.Str(", " .. str(ref.volume))} end
    if ref.page then inl:extend{pandoc.Str(", " .. str(ref.page):gsub("%-+", "–"))} end
    inl:insert(pandoc.Str("."))
  end

  local doi = str(ref.DOI or ref.doi)
  local url = str(ref.URL or ref.url)
  if doi ~= "" then
    inl:insert(pandoc.Space())
    inl:insert(pandoc.Link("doi:" .. doi, "https://doi.org/" .. doi))
  elseif url ~= "" then
    inl:insert(pandoc.Space())
    inl:insert(pandoc.Link("Link", url))
  end
  return pandoc.Para(inl)
end

local function resolve(path)
  local input = (quarto and quarto.doc and quarto.doc.input_file) or PANDOC_STATE.input_files[1]
  if input and not path:match("^/") then
    local dir = pandoc.path.directory(input)
    if dir ~= "" and dir ~= "." then return pandoc.path.join({ dir, path }) end
  end
  return path
end

local cache

local function load_refs()
  if cache then return cache.refs, cache.errors end
  local refs, seen, errors = {}, {}, {}
  for _, f in ipairs(bibfiles) do
    local fh = io.open(resolve(f), "r")
    if not fh then
      table.insert(errors, pandoc.Para{ pandoc.Str("[Could not read " .. f .. "]") })
    else
      local text = fh:read("a"); fh:close()
      for _, r in ipairs(pandoc.read(text, "bibtex").meta.references or {}) do
        -- skip duplicates (same DOI, or same title when there is no DOI)
        local key = str(r.DOI or r.doi):lower()
        if key == "" then key = str(r.title):lower() end
        if not seen[key] then seen[key] = true; refs[#refs + 1] = r end
      end
    end
  end
  cache = { refs = refs, errors = errors }
  return refs, errors
end

-- position of the highlighted author in the author list (nil if absent)
local function my_position(ref)
  for i, a in ipairs(ref.author or {}) do
    if str(a.family) == highlight then return i end
  end
end

local function stats_block()
  local refs = load_refs()
  local total, first, cofirst = #refs, 0, 0
  for _, r in ipairs(refs) do
    local pos = my_position(r)
    if pos == 1 then
      first = first + 1
    elseif pos and equal_positions(r)[pos] and equal_positions(r)[1] then
      cofirst = cofirst + 1
    end
  end
  local txt = total .. " publications, including " .. first .. " as first author"
  if cofirst > 0 then
    txt = txt .. " and " .. cofirst .. " as co-first author*"
  end
  return pandoc.Para{ pandoc.Strong(pandoc.Str(txt)) }
end

local function build()
  local refs, errors = load_refs()
  local blocks = {}
  for _, e in ipairs(errors) do blocks[#blocks + 1] = e end

  local items = {}
  for i, r in ipairs(refs) do items[#items + 1] = { ref = r, year = year_of(r), month = str(r.issued):match("%d%d%d%d%-(%d%d)") or "00", idx = i } end
  -- newest first (year, then month); ties keep file order
  table.sort(items, function(a, b)
    if a.year ~= b.year then return a.year > b.year end
    if a.month ~= b.month then return a.month > b.month end
    return a.idx < b.idx
  end)

  local current
  for _, it in ipairs(items) do
    if it.year ~= current then
      current = it.year
      table.insert(blocks, pandoc.Header(2, current, pandoc.Attr("year-" .. current)))
    end
    table.insert(blocks, entry_para(it.ref))
  end
  return blocks
end

return {
  {
    Meta = function(meta)
      local pb = meta["publications-bib"]
      if pb then
        bibfiles = {}
        if pandoc.utils.type(pb) == "List" then
          for _, f in ipairs(pb) do bibfiles[#bibfiles + 1] = str(f) end
        else
          bibfiles = { str(pb) }
        end
      end
      if meta["equal-contribution"] then
        for doi, pos in pairs(meta["equal-contribution"]) do equal_by_doi[str(doi):lower()] = str(pos) end
      end
      if meta["highlight-author"] then highlight = str(meta["highlight-author"]) end
      if meta["keep-case"] then
        for _, w in ipairs(meta["keep-case"]) do keep_case[str(w)] = true end
      end
    end
  },
  {
    Div = function(div)
      if div.identifier == "publication-stats" then
        return pandoc.Div({ stats_block() }, pandoc.Attr("publication-stats", { "pub-stats" }))
      end
      if div.identifier == "publication-list" then
        return pandoc.Div(build(), pandoc.Attr("publication-list", { "pub-list" }))
      end
    end
  }
}
