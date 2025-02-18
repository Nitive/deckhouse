module Jekyll
  module Openapi

    def format_key_name(name)
      "<code class=\"highlighter-rouge\">#{name}</code>"
    end

    #
    # Return localised description
    # the source parameter is for object without i18n structure and for legacy support
    def get_i18n_description(primaryLanguage, fallbackLanguage, source=nil)
        if primaryLanguage and primaryLanguage.has_key?("description") then
            result = primaryLanguage["description"]
        elsif fallbackLanguage and fallbackLanguage.has_key?("description") then
            result = fallbackLanguage["description"]
        elsif source and source.has_key?("description") then
            result = source["description"]
        else
            result = nil
        end
        result
    end

    def get_i18n_term(term)
        lang = @context.registers[:page]["lang"]
        i18n = @context.registers[:site].data["i18n"]["common"]

        if ! i18n[term]
            result = term
            puts "NOTE: No i18n for the term '" + term + "'!"
        else
            result =i18n[term][lang]
        end
        result
    end

    def get_hash_value(input, *keys)
        input ? input.dig(*keys) : nil
    end

    def format_type(first_type, second_type)
        lang = @context.registers[:page]["lang"]
        i18n = @context.registers[:site].data["i18n"]["common"]

        if !i18n[first_type] then
            result = first_type
            puts "NOTE: No i18n for the '" + first_type + "' type!"
        else
            result = i18n[first_type][lang]
        end
        if second_type then
            result += ' ' + i18n['of'][lang]
            if !i18n[second_type] then
                result += " #{second_type}"
                puts "NOTE: No i18n for the 'of " + first_type + "' type!"
            else
                result += ' ' + i18n['of_' + second_type][lang]
            end
        end
        result
    end

    def format_attribute(name, attributes, parent, primaryLanguage = nil, fallbackLanguage = nil)
        result = Array.new()
        exampleObject = nil
        converter = Jekyll::Converters::Markdown::KramdownParser.new(Jekyll.configuration())

        result.push(converter.convert(get_i18n_description(primaryLanguage, fallbackLanguage, attributes))) if attributes['description']

        if attributes.has_key?('x-doc-default')
            if attributes['x-doc-default'].is_a?(Array)
                result.push(converter.convert('**' + get_i18n_term("default_value").capitalize + ":** `#{attributes['x-doc-default'].to_json}`"))
            else
                if attributes['type'] == 'string'
                    result.push(converter.convert('**' + get_i18n_term("default_value").capitalize + ":** `\"#{attributes['x-doc-default']}\"`"))
                else
                    result.push(converter.convert('**' + get_i18n_term("default_value").capitalize + ":** `#{attributes['x-doc-default']}`"))
                end
            end
        elsif attributes.has_key?('default')
            if attributes['default'].is_a?(Array)
                result.push(converter.convert('**' + get_i18n_term("default_value").capitalize + ":** `#{attributes['default'].to_json}`"))
            else
                if attributes['type'] == 'string'
                    result.push(converter.convert('**' + get_i18n_term("default_value").capitalize + ":** `\"#{attributes['default']}\"`"))
                else
                    result.push(converter.convert('**' + get_i18n_term("default_value").capitalize + ":** `#{attributes['default']}`"))
                end
            end
        end

        if attributes.has_key?('x-doc-versionType')
          case attributes['x-doc-versionType']
          when "ee"
            result.push(converter.convert('**' + @context.registers[:site].data['i18n']['features']['ee']['ru'].capitalize + '**'))
          when "experimental"
            result.push(converter.convert('**' + @context.registers[:site].data['i18n']['features']['experimental'][lang].capitalize + '**'))
          end
        end

        if attributes['minimum'] || attributes['maximum']
            range = '**' + get_i18n_term("allowed_values").capitalize + ':** `'
            if attributes['minimum']
              comparator = attributes['exclusiveMinimum'] ? '<' : '<='
              range += "#{attributes['minimum'].to_json} #{comparator} "
            end
            range += ' X '
            if attributes['maximum']
              comparator = attributes['exclusiveMaximum'] ? '<' : '<='
              range += " #{comparator} #{attributes['maximum'].to_json}"
            end
            range += '`'
            result.push(converter.convert(range.to_s))
        end

        if attributes['enum']
            enum_result = '**' + get_i18n_term("allowed_values").capitalize
            if name == "" and parent['type'] == 'array'
                enum_result += ' ' + get_i18n_term("allowed_values_of_array")
            end
            result.push(converter.convert(enum_result + ':** ' + [*attributes['enum']].map { |e| "`#{e}`" }.join(', ')))
        end

        if attributes['pattern']
            result.push(converter.convert('**' + get_i18n_term("pattern").capitalize + ":** `#{attributes['pattern']}`"))
        end

        if attributes['minLength'] || attributes['maxLength']
            description = '**' + get_i18n_term('length').capitalize + ':** `'
            if attributes['minLength']
              description += "#{attributes['minLength'].to_json}"
            end
            unless attributes['minLength'] == attributes['maxLength']
              if attributes['maxLength']
                unless attributes['minLength']
                  description += '0'
                end
                description += "..#{attributes['maxLength'].to_json}"
              else
                description += '..∞'
              end
            end
            description += '`'
            result.push(converter.convert(description.to_s))
        end

        if attributes.has_key?('x-doc-example')
            exampleObject = attributes['x-doc-example']
        elsif attributes.has_key?('example')
            exampleObject = attributes['example']
        elsif attributes.has_key?('x-examples')
            exampleObject = attributes['x-examples']
        end
        if exampleObject != nil
            example =  '**' + get_i18n_term('example').capitalize + ':** ' +
                        if exampleObject.is_a?(Hash) && exampleObject.has_key?('oneOf')
                            exampleObject['oneOf'].map { |e| "`#{e.to_json}`" }.join(' ' + get_i18n_term('or') + ' ')
                        elsif exampleObject.is_a?(Array) || exampleObject.is_a?(Hash)
                            '`' + exampleObject.map { |e| "`#{e.to_json}`" }.join('`, `') + '`'
                        else
                            if attributes['type'] == 'string'
                                "`\"#{exampleObject}\"`"
                            else
                                "`#{exampleObject}`"
                            end
                        end
            result.push(converter.convert(example.to_s))
        end

        if parent.has_key?('required') && parent['required'].include?(name)
            result.push(converter.convert('**' + get_i18n_term('required_value_sentence')  + '**'))
        elsif attributes.has_key?('x-doc-required')
            if attributes['x-doc-required']
                result.push(converter.convert('**' + get_i18n_term('required_value_sentence')  + '**'))
            else
                result.push(converter.convert('**' + get_i18n_term('not_required_value_sentence')  + '**'))
            end
        else
            # Not sure if there will always be an optional value here...
            # result.push(converter.convert('**' + get_i18n_term('not_required_value_sentence')  + '**'))
        end
        result
    end

    # params:
    # 1 - parameter name to render (string)
    # 2 - parameter attributes (hash)
    # 3 - parent item data (hash)
    # 4 - object with primary language data
    # 5 - object with language data which use if there is no data in primary language
    def format_schema(name, attributes, parent, primaryLanguage = nil, fallbackLanguage = nil)
        result = Array.new()

        if name != ""
            result.push('<li>')
            attributes_type = ''
            if attributes.has_key?('type')
               attributes_type = attributes["type"]
            elsif attributes.has_key?('x-kubernetes-int-or-string')
               attributes_type = "x-kubernetes-int-or-string"
            end
            if attributes_type != ''
                if attributes.has_key?("items")
                    result.push(format_key_name(name)+ ' (<i>' +  format_type(attributes_type, attributes["items"]["type"]) + '</i>)')
                else
                    result.push(format_key_name(name)+ ' (<i>' +  format_type(attributes_type, nil) + '</i>)')
                end
            else
                result.push(format_key_name(name))
            end
        end

        result.push(format_attribute(name, attributes, parent, primaryLanguage, fallbackLanguage))

        if attributes.has_key?("properties")
            result.push('<ul>')
            attributes["properties"].sort.to_h.each do |key, value|
                result.push(format_schema(key, value, attributes, get_hash_value(primaryLanguage, "properties", key), get_hash_value(fallbackLanguage, "properties", key)))
            end
            result.push('</ul>')
        elsif attributes.has_key?('items')
            if get_hash_value(attributes,'items','properties')
                # object items
                result.push('<ul>')
                attributes['items']["properties"].sort.to_h.each do |item_key, item_value|
                    result.push(format_schema(item_key, item_value, attributes['items'], get_hash_value(primaryLanguage,"items", "properties", item_key) , get_hash_value(fallbackLanguage,"items", "properties", item_key)))
                end
                result.push('</ul>')
            else
                result.push(format_schema("", attributes['items'], attributes, get_hash_value(primaryLanguage,'items'), get_hash_value(fallbackLanguage,'items') ))
            end
        else
            # result.push("no properties for #{name}")
        end
        if name != ""
            result.push('</li>')
        end
        result.join
    end

    def format_crd(input)

        return nil if !input

        if ( @context.registers[:page]["lang"] == 'en' )
            fallbackLanguageName = 'ru'
        else
            fallbackLanguageName = 'en'
        end
        result = []
        if !( input.has_key?('i18n'))
           input['i18n'] = {}
        end
        if !( input['i18n'].has_key?('en'))
           input['i18n']['en'] = { "spec" => input["spec"] }
        end
        result.push('<div markdown="0">')
        if ( get_hash_value(input,'spec','validation','openAPIV3Schema')  ) or (get_hash_value(input,'spec','versions'))
           then
            converter = Jekyll::Converters::Markdown::KramdownParser.new(Jekyll.configuration())

            if get_hash_value(input,'spec','validation','openAPIV3Schema') then
                # v1beta1 CRD

                result.push(converter.convert("## " + input["spec"]["names"]["kind"]))
                result.push('<p><font size="-1">Scope: ' + input["spec"]["scope"])
                if input["spec"].has_key?("version") then
                   result.push('<br/>Version: ' + input["spec"]["version"] + '</font></p>')
                end

                if get_hash_value(input,'spec','validation','openAPIV3Schema','description')
                   if get_hash_value(input['i18n'][@context.registers[:page]["lang"]],"spec","validation","openAPIV3Schema","description") then
                       result.push(converter.convert(get_hash_value(input['i18n'][@context.registers[:page]["lang"]],"spec","validation","openAPIV3Schema","description")))
                   elsif get_hash_value(input['i18n'][fallbackLanguageName],"spec","validation","openAPIV3Schema","description") then
                       result.push(converter.convert(input['i18n'][fallbackLanguageName]["spec"]["validation"]["openAPIV3Schema"]["description"]))
                   else
                       result.push(converter.convert(input["spec"]["validation"]["openAPIV3Schema"]["description"]))
                   end
                end

                if input["spec"]["validation"]["openAPIV3Schema"].has_key?('properties')
                    result.push('<ul>')
                    input["spec"]["validation"]["openAPIV3Schema"]['properties'].sort.to_h.each do |key, value|
                    _primaryLanguage = nil
                    _fallbackLanguage = nil

                    if  input['i18n'][@context.registers[:page]["lang"]] then
                        _primaryLanguage = get_hash_value(input['i18n'][@context.registers[:page]["lang"]],"spec","validation","openAPIV3Schema","properties",key)
                    end
                    if   input['i18n'][fallbackLanguageName] then
                        _fallbackLanguage = get_hash_value(input['i18n'][fallbackLanguageName],"spec","validation","openAPIV3Schema","properties",key)
                    end
                        result.push(format_schema(key, value, input["spec"]["validation"]["openAPIV3Schema"], _primaryLanguage, _fallbackLanguage ))
                    end
                    result.push('</ul>')
                end
            elsif input.has_key?("spec") and input["spec"].has_key?("versions") then
                # v1+ CRD

                 result.push(converter.convert("## " + input["spec"]["names"]["kind"]))

                 if  input["spec"]["versions"].length > 1 then
                     result.push('<p><font size="-1">Scope: ' + input["spec"]["scope"] + '</font></p>')
                     result.push('<div class="tabs">')
                     activeStatus=" active"
                     input["spec"]["versions"].each do |item|
                         #result.push(" onclick=\"openTab(event, 'tabs__btn', 'tabs__content', " + input["spec"]["names"]["kind"].downcase + '_' + item['name'].downcase + ')">' + item['name'].downcase + '</a>')
                         result.push("<a href='javascript:void(0)' class='tabs__btn tabs__btn__%s%s' onclick=\"openTab(event, 'tabs__btn__%s', 'tabs__content__%s', '%s_%s')\">%s</a>" %
                           [ input["spec"]["names"]["kind"].downcase, activeStatus,
                             input["spec"]["names"]["kind"].downcase,
                             input["spec"]["names"]["kind"].downcase,
                             input["spec"]["names"]["kind"].downcase, item['name'].downcase,
                             item['name'].downcase ])
                         activeStatus = ""
                     end
                     result.push('</div>')
                 end

                 activeStatus=" active"
                 input["spec"]["versions"].each do |item|
                    _primaryLanguage = nil
                    _fallbackLanguage = nil

                    if input["spec"]["versions"].length == 1 then
                        result.push('<p><font size="-1">Scope: ' + input["spec"]["scope"])
                        result.push('<br/>Version: ' + item['name'] + '</font></p>')
                    else
                        #result.push(converter.convert("### " + item['name'] + ' {#' + input["spec"]["names"]["kind"].downcase + '-' + item['name'].downcase + '}'))
                        #result.push('<p><font size="-1">Scope: ' + input["spec"]["scope"] + '</font></p>')
                    end

                    if input["spec"]["versions"].length > 1 then
                        result.push("<div id='%s_%s' class='tabs__content tabs__content__%s%s'>" %
                            [ input["spec"]["names"]["kind"].downcase, item['name'].downcase,
                            input["spec"]["names"]["kind"].downcase, activeStatus ])
                        activeStatus = ""
                    end

                    if get_hash_value(item,'schema','openAPIV3Schema','description') then
                       if  input['i18n'][@context.registers[:page]["lang"]] and
                           get_hash_value(input['i18n'][@context.registers[:page]["lang"]],"spec","versions") and
                           input['i18n'][@context.registers[:page]["lang"]]["spec"]["versions"].select {|i| i['name'].to_s == item['name'].to_s; }[0] then
                       result.push(converter.convert(input['i18n'][@context.registers[:page]["lang"]]["spec"]["versions"].select {|i| i['name'].to_s == item['name'].to_s; }[0]["schema"]["openAPIV3Schema"]["description"]))
                       elsif input['i18n'][fallbackLanguageName] and
                             get_hash_value(input['i18n'][fallbackLanguageName],"spec","versions") and
                            input['i18n'][fallbackLanguageName]["spec"]["versions"].select {|i| i['name'].to_s == item['name'].to_s; }[0] then
                       result.push(converter.convert(input['i18n'][fallbackLanguageName]["spec"]["versions"].select {|i| i['name'].to_s == item['name'].to_s; }[0]["schema"]["openAPIV3Schema"]["description"]))
                       else
                           result.push(converter.convert(item["schema"]["openAPIV3Schema"]["description"]))
                       end
                    end

                    if get_hash_value(item,'schema','openAPIV3Schema','properties')
                        header = '<ul>'
                        item['schema']['openAPIV3Schema']['properties'].each do |key, value|
                        _primaryLanguage = nil
                        _fallbackLanguage = nil
                        # skip status object
                        next if key == 'status'
                        if header != '' then
                            result.push(header)
                            header = ''
                        end

                        if  input['i18n'][@context.registers[:page]["lang"]] and
                            get_hash_value(input['i18n'][@context.registers[:page]["lang"]],"spec","versions") and
                            input['i18n'][@context.registers[:page]["lang"]]["spec"]["versions"].select {|i| i['name'].to_s == item['name'].to_s; }[0]
                        then
                            _primaryLanguage = input['i18n'][@context.registers[:page]["lang"]]["spec"]["versions"].select {|i| i['name'].to_s == item['name'].to_s; }[0]
                            _primaryLanguage = get_hash_value(_primaryLanguage,'schema','openAPIV3Schema','properties',key)
                        end
                        if  input['i18n'][fallbackLanguageName] and
                            get_hash_value(input['i18n'][fallbackLanguageName],"spec","versions") and
                            input['i18n'][fallbackLanguageName]["spec"]["versions"].select {|i| i['name'].to_s == item['name'].to_s; }[0]
                        then
                            _fallbackLanguage = input['i18n'][fallbackLanguageName]["spec"]["versions"].select {|i| i['name'].to_s == item['name'].to_s; }[0]
                            _fallbackLanguage = get_hash_value(_fallbackLanguage,'schema','openAPIV3Schema','properties',key)
                        end

                        result.push(format_schema(key, value, item['schema']['openAPIV3Schema'] , _primaryLanguage, _fallbackLanguage))
                        end
                        if header == '' then
                            result.push('</ul>')
                        end
                    end

                    if get_hash_value(input,'spec','versions').length > 1 then
                        result.push("</div>")
                    end

                 end
            end
        end
        result.push('</div>')
        result.join
    end

    #
    # Returns configuration module content from the openAPI spec
    def format_configuration(input)
        result = []
        result.push('<div markdown="0">')
        if !( input.has_key?('i18n'))
           input['i18n'] = {}
        end
        if !( input['i18n'].has_key?('en'))
           input['i18n']['en'] = { "properties" => input['properties'] }
        end
        if ( input.has_key?("properties"))
           then
            converter = Jekyll::Converters::Markdown::KramdownParser.new(Jekyll.configuration())

            result.push('<ul>')
            input['properties'].sort.to_h.each do |key, value|
                _primaryLanguage = nil
                _fallbackLanguage = nil

                if ( input['i18n'].has_key?(@context.registers[:page]["lang"]) and input['i18n'][@context.registers[:page]["lang"]].has_key?("properties") )
                    _primaryLanguage = input['i18n'][@context.registers[:page]["lang"]]["properties"][key]
                end
                if ( @context.registers[:page]["lang"] == 'en' )
                    fallbackLanguageName = 'ru'
                else
                    fallbackLanguageName = 'en'
                end
                if ( input['i18n'].has_key?(fallbackLanguageName) and input['i18n'][fallbackLanguageName].has_key?("properties") )
                    _fallbackLanguage = input['i18n'][fallbackLanguageName]["properties"][key]
                end
                result.push(format_schema(key, value, input, _primaryLanguage, _fallbackLanguage ))
            end
            result.push('</ul>')
        end
        result.push('</div>')
        result.join
    end
  end
end

Liquid::Template.register_filter(Jekyll::Openapi)
