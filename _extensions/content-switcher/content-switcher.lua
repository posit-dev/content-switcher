-- content-switcher.lua
-- A filter for content switching in Quarto documents

-- Define defaults
local default_version = "default"
local versions = {}
local version_set = {}             -- Hash table for O(1) version lookups
local selector_position = "header" -- Where to place the selector (header/top, after-first-heading, before-content, after-section)
local show_selector = true         -- Whether to show the version selector
local selector_label = "Version:"  -- Label text for the selector
local after_section_heading = nil   -- Heading text to match for after-section positioning

-- Parse configuration from document metadata
function get_config(meta)
  -- Get config from document metadata
  local extensions = meta["extensions"]
  local config = extensions and extensions["content-switcher"]

  if config ~= nil then
    -- Get default version if specified
    if config["default"] ~= nil then
      default_version = pandoc.utils.stringify(config["default"])
    end

    -- Get versions if specified
    if config["versions"] ~= nil then
      for _, version in ipairs(config["versions"]) do
        if type(version) == "table" then
          -- Handle detailed version specification with ID and label
          local id = pandoc.utils.stringify(version["id"])
          local label = pandoc.utils.stringify(version["label"] or id)
          table.insert(versions, { id = id, label = label })
          version_set[id] = true
        else
          -- Handle simple version string
          local id = pandoc.utils.stringify(version)
          table.insert(versions, { id = id, label = id })
          version_set[id] = true
        end
      end
    end

    -- Get selector configuration if specified
    local selector_config = config["selector"]
    if selector_config ~= nil then
      -- Boolean shorthand: selector: true / selector: false
      local stringified = pandoc.utils.stringify(selector_config)
      if stringified == "true" or stringified == "false" then
        show_selector = (stringified == "true")
      else
        -- Object form: selector: { position, label, show }
        if selector_config["position"] ~= nil then
          selector_position = pandoc.utils.stringify(selector_config["position"])
        end
        if selector_config["show"] ~= nil then
          show_selector = (pandoc.utils.stringify(selector_config["show"]) == "true")
        end
        if selector_config["label"] ~= nil then
          selector_label = pandoc.utils.stringify(selector_config["label"])
        end
        if selector_config["after-section-heading"] ~= nil then
          after_section_heading = pandoc.utils.stringify(selector_config["after-section-heading"])
        end
      end
    end
  end

  -- If no versions defined but we have conditional blocks, add defaults based on what we find
  if #versions == 0 then
    quarto.log.output("No versions defined in metadata, will auto-detect")
  end
end

-- Add a version dynamically if discovered in content
function add_version_if_new(version)
  -- Don't add empty versions
  if version == nil or version == "" then
    return
  end

  -- Check if this version already exists (O(1) hash table lookup)
  if version_set[version] then
    return -- Already exists
  end

  -- Add the new version to both structures
  version_set[version] = true
  table.insert(versions, { id = version, label = version })
  quarto.log.output("Added version: " .. version)
end

-- Escape special HTML characters
local function escape_html(str)
  return str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

-- Generate version selector HTML
function generate_version_selector()
  if #versions == 0 or not show_selector then
    return ""
  end

  local html = '<div class="content-switcher-selector">\n'
  html = html .. '  <label for="content-switcher-select">' .. escape_html(selector_label) .. '</label>\n'
  html = html .. '  <select id="content-switcher-select" aria-label="Select content version">\n'

  for _, version in ipairs(versions) do
    local selected = ""
    if version.id == default_version then
      selected = ' selected="selected"'
    end
    html = html ..
    '    <option value="' ..
    escape_html(version.id) .. '"' .. selected .. '>' .. escape_html(version.label) .. '</option>\n'
  end

  html = html .. '  </select>\n'
  html = html .. '</div>\n'

  return html
end

-- Helper function to mark headers as unlisted (not used by default)
-- Users can manually add {.unlisted} to headers if they want to exclude from TOC
-- local function mark_headers_unlisted(content)
--   return pandoc.walk_block(content, {
--     Header = function(header)
--       header.classes:insert("unlisted")
--       return header
--     end
--   })
-- end

-- Helper function to process conditional elements (both Div and Span)
local function process_conditional_element(element)
  -- Only process elements with content-switcher class
  if not element.classes:includes("content-switcher") then
    return element
  end

  -- Get version (default if not specified)
  local version = element.attributes["version"] or default_version
  add_version_if_new(version)

  -- For HTML output, set up for dynamic switching
  if quarto.doc.is_format("html") then
    -- Don't add content-switcher-hidden class here to ensure all content
    -- is indexed by Quarto's search. JavaScript will handle hiding.
    return element
  end

  -- For non-HTML output, only show the default version
  if version == default_version then
    return element
  else
    return {}
  end
end

-- Main filter function
function process_document(doc)
  -- Only for HTML with versions, inject selector and JavaScript
  if quarto.doc.is_format("html") and #versions > 0 then
    local selector_html = generate_version_selector()

    quarto.doc.add_html_dependency({
      name = "content-switcher",
      version = "0.1.0",
      scripts = { "content-switcher.js" },
      stylesheets = { "content-switcher.css" }
    })

    if show_selector then
      local insert_position = 1 -- Default to top

      -- Find position based on selector_position setting
      if selector_position == "header" or selector_position == "top" then
        insert_position = 1
      elseif selector_position == "after-first-heading" then
        -- Legacy behavior: place after first content heading (H2, H3, etc.)
        for idx, block in ipairs(doc.blocks) do
          if block.t == "Header" then
            insert_position = idx + 1
            break
          end
        end
      elseif selector_position == "before-content" then
        -- Place the selector just before the quarto-content div, which sits
        -- after the title block and any front-matter elements.
        for idx, block in ipairs(doc.blocks) do
          if block.t == "Div" and block.classes:includes("quarto-content") then
            insert_position = idx
            break
          end
        end
      elseif selector_position == "after-section" and after_section_heading ~= nil then
        -- Place the selector at the end of a specific section, identified by
        -- heading text (case-insensitive). Useful for long guides where the
        -- content switch maps to a user decision made mid-page rather than at
        -- the top. Falls back to default (top) if the heading isn't found.
        local target_idx = nil
        local target_level = nil
        for idx, block in ipairs(doc.blocks) do
          if block.t == "Header" and pandoc.utils.stringify(block.content):lower() == after_section_heading:lower() then
            target_idx = idx
            target_level = block.level
            break
          end
        end
        if target_idx ~= nil then
          -- Walk forward until we hit a heading at the same level or higher,
          -- which marks the start of the next section.
          local found_end = false
          for idx = target_idx + 1, #doc.blocks do
            if doc.blocks[idx].t == "Header" and doc.blocks[idx].level <= target_level then
              insert_position = idx
              found_end = true
              break
            end
          end
          if not found_end then
            insert_position = #doc.blocks + 1
          end
        end
      end

      table.insert(doc.blocks, insert_position, pandoc.RawBlock("html", selector_html))
    end
  end

  return doc
end

-- Register the filter functions
return {
  { Meta = get_config },
  { Span = process_conditional_element },
  { Div = process_conditional_element },
  { Pandoc = process_document }
}
