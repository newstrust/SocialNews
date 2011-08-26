## FIXME: Rewrite this module to handle options as a hash rather than as method arguments
## There is no benefit to passing arguments in the classical sense because there is no static type-checking anyway

module StringHelpers
  @@separators = /\s/

  class << self
    def separators=(seps)
      @@separators = seps
    end

    def blank(s)
      s.nil? || s.empty?
    end

    def plain_text(s)
      !blank(s) ? Hpricot(s).inner_text.gsub(/\s+/, ' ').strip : s
    end

    def num_words(s) 
      s.split(/\s+/).length
    end

    def num_words_of_min_length(s, min_len)
      s.split(/\s+/).inject(0) { |n, w| n + ((w.length < min_len) ? 0 : 1)}
    end

      ## return a truncated string from an input string 'str' so that it is at least 'min_chars' and at most 'max_chars'.
      ## Add " ..." to the end if truncated, unless add_trailer is false
      ##
      ## If possible, truncate on a word boundary -- but, requires that min_chars and max_chars be big enough to allow
      ## for a word separator to exist in there!  There is no guarantee that it will truncate on a word boundary.
    def truncate(str, min_chars, max_chars, word_boundary_only=false, start_offset=0, add_trailer=true, more_url_link="")
      return "" if blank(str)

        ## Fetch the substring
      s = (start_offset == 0) ? str: str[start_offset..start_offset+max_chars] 

        ## Clone so that behavior is consistent -- in all other cases, a string different from 'str' is returned
      return ((start_offset == 0) ? s.clone : s) if (s.length <= max_chars) 

      char_offset = max_chars - 1
      if (add_trailer)
        char_offset -= 4 # because we are going to append " ..." at the end
        min_chars   -= 4 # because we are going to append " ..." at the end
      end
      unless blank(more_url_link)
        char_offset -= 7 # because we are going to append " More >>" at the end
        min_chars   -= 7 # because we are going to append " More >>" at the end
      end
      s = s[0..char_offset]

      more_trailer = blank(more_url_link) ? "" : " #{more_url_link}"

      pos = s.rindex(@@separators)
      if (!pos.nil? && (pos >= min_chars))
        s = s[0..pos-1]
        return (add_trailer) ? s + ' ...' + more_trailer : s
      elsif (word_boundary_only)
        nil  ## Return nil so that the user knows that this is an exceptional condition and handles it appropriately
      else
        s[char_offset] = '-' ## Indicate that the word was truncated mid-way!
        return (add_trailer) ? s + ' ...' + more_trailer : s
      end
    end

      # Helpful wrapper around truncate
    def truncate_on_word_boundary(str, min_len, max_len, spillover_if_necessary=false, start_offset=0, add_trailer=true)
      return "" if blank(str)
      more_url_link = yield if block_given?
      s = truncate(str, min_len, max_len, true, start_offset, add_trailer, more_url_link)
      return s if !s.nil?

        ## What to do if we fail?
      if s.nil? && spillover_if_necessary
        i = str[start_offset+max_len..str.length].index(@@separators)
        return str if i.nil?

        retval = str[start_offset..start_offset+max_len+i-1]
        retval += "..." if add_trailer
        retval += " #{more_url_link}" unless blank(more_url_link)
        return retval
      else
        return nil  ## Return nil so that the user knows that this is an exceptional condition and handles it appropriately
      end
    end

      # Line wrapping code that leverages the truncate functionality
    def linewrap_text(orig_line, max_line_length)
      orig_line.gsub!(/\A\s*|\s*\z/m, '')
      line_array = []
        # Split the string at line-boundaries
      orig_line.split("\n").each { |s|
        start_offset = 0
        s_len = s.length

          ## Process the string in line-size segments 
        while ((start_offset + max_line_length) < s_len) do
          line = truncate_on_word_boundary(s, 15, max_line_length, true, start_offset, false)
          line_array << line
          start_offset += line.length
          start_offset += 1 if (start_offset < s_len && s[start_offset..start_offset] =~ /\s/)
        end

          ## Last segment of the string
        line_array << s[start_offset..s_len]
      }

      return line_array.join("\n")
    end
  end
end
