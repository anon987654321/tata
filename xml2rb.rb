require 'nokogiri'
require 'fileutils'

# Converts an XML node to a nested hash structure
def to_hash(node)
  return nil if node.nil?

  result_hash = {}
  node.element_children.each do |child|
    if child.name == "Element" && child.attributes['Row'] && child.attributes['Col']
      row = child.attributes["Row"].value
      col = child.attributes["Col"].value
      result_hash["#{row},#{col}"] = child.text.strip
    else
      child_hash = to_hash(child)
      result_hash[child.name] = child_hash unless child_hash.nil?
    end
  end

  # If the node doesn't have child elements, return its text content
  result_hash.empty? ? node.text.strip : result_hash
end

# Cleans up the nested hash by stripping strings and removing unnecessary whitespace
def clean(h)
  if h.is_a?(Hash)
    h.transform_values do |v|
      if v.is_a?(String)
        cleaned_value = v.strip
        cleaned_value = cleaned_value.tr("\n", '').squeeze(' ') unless cleaned_value.empty?
        cleaned_value
      elsif v.is_a?(Hash) || v.is_a?(Array)
        clean(v) unless v.empty?
      else
        v
      end
    end
  elsif h.is_a?(Array)
    h.map { |v| clean(v) }
  else
    h
  end
end

# Converts an XML file to a Ruby hash and writes it to a .rb file
def convert_xml_to_ruby_hash(file)

  # Skip already processed files
  return if $processed_files.include?(file)
  $processed_files << file

  doc = File.open(file) { |f| Nokogiri::XML(f) }

  # Convert XML to nested hash and clean up
  hash = {'dcpData' => to_hash(doc.root)}
  hash = clean(hash)

  if hash.nil?
    puts "Error: hash object is nil"
    return
  end

  if !hash.key?('dcpData') || hash['dcpData'].nil?
    puts "Error: 'dcpData' key not found in hash"
    return
  end

  # Create target directory and file paths
  target_dir = File.join(Dir.pwd, 'cameras')
  FileUtils.mkdir_p(target_dir) unless Dir.exist?(target_dir)

  # Use the original XML file name for the generated Ruby file name
  original_file_name = File.basename(file, '.xml')
  target_file = File.join(target_dir, "#{original_file_name}.rb")

  # Write the cleaned hash to the target .rb file
  File.write(target_file, hash.to_s)
  puts target_file
rescue NoMethodError => e
  puts "NoMethodError encountered in convert_xml_to_ruby_hash"
  puts "Error message: #{e.message}"
end

# Track processed files
$processed_files = []

# Iterate over all .xml files in subdirectories and convert them to .rb files

puts "Converting Adobe DCP/XML presets to Ruby hashes..."

Dir.glob('**/*.xml').each do |xml_file|
  convert_xml_to_ruby_hash(xml_file)
end

