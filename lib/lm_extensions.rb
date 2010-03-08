# Liquid Media RoR support code
# Copyright 2007 Liquid Media
# This should all be factored out into a Rails plug-in.
class LMFormBuilder < ActionView::Helpers::FormBuilder

  # Keep a copy of the old submit method around
  alias_method :naked_submit, :submit
  
  # Smart url field - automatically inserts http:// on focus, removes it on blur if nothing has been added,
  # prefixes http:// if no protocol is included
  def url_field(name, options = {})
    text_field(name, options.merge!({ :onfocus => "if(this.value==''){this.value='http://';this.select();}",
        :onblur => "if (this.value == 'http://') { \
                      this.value = ''; \
                    } else if (this.value != '') { \
                      var search = /^\\w{3,5}:\\/\\//; \
                      var result = this.value.match(search); \
                      if (result == null) { \
                        this.value = 'http://' + this.value; \
                      } \
                    }"}))
  end

  def self.create_tagged_field(method_name)
    define_method(method_name) do |label, *args|
      human_name = label.to_s.humanize
      greyed = ""

      # This will let us override the label by doing something like:
      # form_builder.text_field :first, :human_name => "First name"
      options_hash = args[0]
      options_hash = args[1] if method_name == :select
      if options_hash.is_a?(Hash)
        if options_hash[:human_name].not_blank?
          human_name = options_hash[:human_name]
          options_hash.delete_if{|k,v| k==:human_name}
        end
        if options_hash[:required]
          human_name += "<span class=\"required\">*</span>"
          options_hash.delete_if{|k,v| k==:required}
        end
        if options_hash[:greyed]
          greyed = "greyed"
          options_hash.delete_if{|k,v| k==:greyed}
        end
      end

      case method_name
      when :space
        @template.content_tag("span",
          @template.content_tag("label", "&nbsp;", :for => "") + label, :class => "field #{"greyed" if greyed.not_blank?}")
      when :link
        @template.content_tag("span",
          @template.content_tag("label", human_name, :for => "#{@object_name}_#{label}") + "«browse widget»",
          :class => "field #{greyed}")
        # One day I hope to create a browse widget which offers some cool ajax-y features. In the meantime, you shouldn't use this method.
      else
        @template.content_tag("span",
          @template.content_tag("label", human_name, :for => "#{@object_name}_#{label}") + super,
          :class => "field #{greyed}")
      end
    end
  end

  [:text_field, :password_field, :text_area, :select, :date_select, :file_field, :space, :link, :submit].each do |name|
    create_tagged_field(name)
  end

  # a similar method exists in Liquid Media's ApplicationHelper
  def safe_submit(label)
    return %Q{<span class="field"><label>&nbsp;</label><input name="commit" type="submit" value="#{label}" onclick="this.disabled=true; this.form.submit();"/></span>}
  end
end

class Object
  # I really want a not_blank? method...
  def not_blank?
    !blank?
  end

  def not_nil?
    !nil?
  end
end

class Array
  # Join all the elements of the array with commas, but also separating the last item from the rest with the word "and".
  #   ["foo"].to_english => "foo"
  #   ["foo", "bar"].to_english => "foo and bar"
  #   ["foo", "bar", "baz"].to_english => "foo, bar, and baz"
  #   ["foo", "bar", "baz", "greeble"].to_english => "foo, bar, baz, and greeble"
  # etc.
  def to_english
    if self.length == 1
      self[0]
    elsif self.length == 2
      self.join(" and ")
    else
      "#{self[0..self.length-2].join(", ")}, and #{self.last}"
    end
  end

  # convert an array [a,b,c,d] to a hash {a=>b, c=>d}
  def to_h
    count = 0
    hash = Hash.new
    (self.length / 2).times do
      hash[self[count]] = self[count+1]
      count += 2
    end
    return hash
  end

end


# Monkey-patch the ApplicationHelper
# This way we keep all form-related methods in one file.
module ApplicationHelper
  # Used in the same context as +form_for+, but generates forms with style. The field tag comes wrapped in a span and preceded by a label. Works with:
  # * +text_field_tag+
  # * +password_field_tag+
  # * +text_area_tag+
  # * +select_tag+
  # * +date_select_tag+
  # * +file_field+
  #
  # There are a few new tags:
  # * +space+ returns an empty label tag. This is used for indenting buttons, as in:
  #   form.space(submit_tag("Click here!")) # =>
  #     <span class="field"><label for="">&nbsp;</label><input name="commit" type="submit" value="Click here!" /></span>
  # * +link+ creates the object-linking widget (for LTA)
  #   form.link('Amicus Brief') # =>
  #     <span class="field"><label for="amicus_brief">Amicus Brief</label><... content of widget ...></span>
  def lm_form_for(name, *args, &block)
    options = args.last.is_a?(Hash) ? args.pop : {}
    options = options.merge(:builder => LMFormBuilder)
    args = (args << options)
    form_for(name, *args, &block)
  end

  # Used in the same context as +fields_for+. See +lm_form_for+ for more information.
  def lm_fields_for(name, *args, &block)
    raise ArgumentError, "Missing block" unless block_given?
    options = args.last.is_a?(Hash) ? args.pop : {}
    options = options.merge(:builder => LMFormBuilder)
    object  = args.first
    yield((options[:builder] || FormBuilder).new(name, object, self, options, block))
  end

  # Wrap the model's attributes in HTML so it looks just the way I like it
  # obj:: the ActiveRecord object
  # For +options+:
  # <tt>:only</tt>:: Displays only these attributes
  # <tt>:except</tt>:: Displays all except these attributes
  # Attributes are displayed in the order specified. Default is to display all. You can override the default by creating a +DISPLAY_ATTRIBUTES+ class constant (recommended) for the object, but the existence of <tt>:only</tt> and <tt>:except</tt> override or modify +DISPLAY_ATTRIBUTES+.
  def model_headerleft(obj, options=Hash.new)
    begin
      display = obj.class::DISPLAY_ATTRIBUTES
    rescue NameError
    end
    display = options[:only].map {|key| key.to_s} if options[:only]
    display = obj.attributes.map {|key,value| key} if display == nil
    display.delete_if {|key| options[:except].include?(key.to_sym)} if options[:except]
    retval = ""
    display.each do |field|
      # Process the value
      value = obj.send(field.to_sym)
      if field[-3..-1] == "_id"
        begin
          klass = field[0..-4]
          helper_method_ref = klass + "_headerleft"
          alt_obj = obj.send(klass.to_sym)
          value = obj.send(klass.to_sym).name

          begin
            value = self.send(helper_method_ref.to_sym, alt_obj)
          rescue NameError
          end
        rescue NoMethodError
        end
      end

      if value.kind_of?(Array)
        response_ary = []
        value.each do |val|
          helper_method_ref = val.class.to_s.underscore+"_headerleft"
          begin
            response_ary << self.send(helper_method_ref.to_sym, val)
          rescue NameError
            response_ary << val.name
          end
        end
        value = response_ary.join ", "
      end

      if value.kind_of?(Time) || value.kind_of?(Date)
        if value > Date.new(1950,1,1)
          # When a date is too long ago, time_ago_in_words falls apart. In early 2008, this was a date in 1901. I'm cutting off any possibility of problems for the next 50 years by going with 1950 instead.
          value = "#{time_ago_in_words(value)} ago (#{value.to_date.to_s(:long)})"
        else
          value = value.to_date.to_s(:long)
        end
      end
      if value.kind_of?(String) && (value[0..6] == "http://" || value[0..7] == "https://")
        value = link_to(value, value)
      end

      retval += field_fmt(field.humanize, value, field) + "\n"
    end
    retval
  end

  # Format a label the way I like it:
  #   <span class="field"><label for="#{label_label}">#{label}</label>#{value}</span>
  # +label+:: The label we'd like to see displayed
  # +value+:: The value we'd like to see next to it
  # +label_label+:: The label for the <label> tag
  def field_fmt(label, value, label_label=nil)
    label_label=label unless label_label
    %Q{<span class="field"><label for="#{label_label}">#{label}<\/label>#{value}<\/span>}
  end

  # just like +field_fmt+, but geared for small forms.
  def field_fmt_small(label, value, label_label=nil)
    label_label=label unless label_label
    %Q{<span class="field"><label for="#{label_label}" class="small">#{label}<\/label>#{value}<\/span>}
  end

  # A simple method to consistently format hints
  def hint(hint)
    "<span class=\"hint\"><strong>Hint:</strong> #{hint}</span>"
  end

  # Returns a hint for hints -- * indicates a required field
  def hint_hint
    "(<span class=\"required\">*</span> indicates a required field)"
  end

  def safe_submit(label)
    return %Q{<input name="commit" type="submit" value="#{label}" onclick="this.disabled=true; this.form.submit();"/>}
  end

  # A hint for textile use
  def textile_hint(what='description')
    hint("Use #{link_to "textile markup", {:controller => 'clearinghouse', :action => 'textile_quickref'}, :popup => ['textile_quickref', 'height=500, width=625, scrollbars=yes']} to add styles to the #{what}.")
  end

  # Returns either <em>class="alternate"</em> or <em>empty string</em>, toggling between the two
  def alternate
    @class = @class != '' ? '' : ' class="alternate"'
  end

  # Same as +alternate+, but returning only the class name without the <tt>class=""</tt> attribute declaration
  def alternate_class
    "alternate" if alternate == " class=\"alternate\""
  end

  # Returns the current value of +alternate+, without toggling
  def alternate_again
    @class
  end

  # Returns the current value of +alternate_class+, without toggling
  def alternate_class_again
    "alternate" if @class == " class=\"alternate\""
  end

  # Format all hour date times consistenly across the UI.
  def format_date(datetime)
    return datetime if !datetime.respond_to?(:strftime)
    datetime.strftime("%m-%d-%Y")
  end

  def format_datetime(datetime)
    return datetime if !datetime.respond_to?(:strftime)
    datetime.strftime("%m-%d-%Y %I:%M %p")
  end

  def website_link(url, length = 17, html_quote = true)
    return "&nbsp;" if url.blank?
    if url.length < 8
      str = url
    elsif url.length >= length
      str = url[7..(length-1)] + "..."
    else
      str = url[7..-1]
    end
    if html_quote
      link_to(h(str), h(url), :title => url)
    else
      link_to(str, url, :title => url)
    end
  end

  # HTML quote, replace URLs with truncated links, truncate overly long words, and convert line breaks.
  # Intended to be used for descriptions and other long texts potentially containing URLs
  # on show pages where we don't want to truncate the text and we want to avoid long URLs
  # extending too far to the right (browser won't wrap them) and breaking the layout.
  # NOTE: Don't truncate the return value of this method as that might mess up the HTML.
  def format_text(text)
    return text if text.blank?

    truncated_text = text.gsub(/\b\S{71,}\b/) do |word|
      if word !~ /^https?:\/\//
        truncate(word, 70)
      else
        word
      end
    end

    simple_format(h(truncated_text).gsub(/\bhttps?:\/\/\S+/) do |word|
      if word =~ /\.$/
        website_link(word.gsub(/\.$/, ''), 70, false) + "." # Remove end of sentence dot from URL
      else
        website_link(word, 70, false)
      end
    end)
  end

  # secure textilize; see the documentation for +textilize+ -- this method is similar, but with :sanitize_html and :filter_styles.
  def stextilize(text)
    if text.blank?
      ""
    else
      if ENV['RAILS_ENV'] == 'test'
        # For some reason, the call to :sanitize_html causes problems in tests. Weird.
        textilized = RedCloth.new(text, [ :hard_breaks, :filter_styles ])
      else
        textilized = RedCloth.new(text, [ :hard_breaks, :sanitize_html, :filter_styles ])
      end
      textilized.to_html
    end
  end


  # Web 2.0-style prettyboxes

  # The whole prettybox. For +html_options+, supply one of: +prettybox_blue+, +prettybox_blush+, +prettybox_green+, +prettybox_grey+, +prettybox_bottomgrey+, +prettybox_limegreen+, +prettybox_palegreen+, +prettybox_raspberry+, +prettybox_skyblue+, +prettybox_yellow+ in the form +:class => "prettybox_blue"+. For +&proc+ supply ERB markup.
  # All the colours +repeat-y+ meaning large prettyboxes get an abrupt change in colour during the gradient. For that, the +prettybox_bottomgrey+ is a convenient alternative, showing a gradient only at the bottom of the prettybox.
  def prettybox(html_options, &proc)
    raise ArgumentError, "Missing block" unless block_given?
    concat(tag("div", html_options, true), proc.binding)
    concat("<div class=\"prettybox_top\">
      <div>&nbsp;</div>
    </div><div class=\"prettybox_inside\">", proc.binding)
    yield
    concat("</div><div class=\"prettybox_bot\">
        <div>&nbsp;</div>
      </div>
    </div>", proc.binding)
  end

  # Return just the top portion of the prettybox (i.e. without the rounded corners at the bottom). See +prettybox+ for explanation of parameters.
  def prettybox_toponly(html_options, &proc)
    raise ArgumentError, "Missing block" unless block_given?
    concat(tag("div", html_options, true), proc.binding)
    concat("<div class=\"prettybox_top\">
      <div>&nbsp;</div>
    </div><div class=\"prettybox_inside\">", proc.binding)
    yield
    concat("</div>
    </div>", proc.binding)
  end

  # Return just the bottom portion of the prettybox (i.e. without the rounded corners at the top). See +prettybox+ for explanation of parameters.
  def prettybox_bottomonly(html_options, &proc)
    raise ArgumentError, "Missing block" unless block_given?
    concat(tag("div", html_options, true), proc.binding)
    concat("<div class=\"prettybox_inside\">", proc.binding)
    yield
    concat("</div><div class=\"prettybox_bot\">
        <div>&nbsp;</div>
      </div>
    </div>", proc.binding)
  end
end
