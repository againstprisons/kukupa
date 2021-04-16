module Kukupa::Helpers::OutsideRequestHelpers
  def outside_request_get_form(form_name)
    unless Kukupa.app_config['outside-request-forms'].key?(form_name)
      return nil
    end

    ###
    # Titles
    ###

    tl_names = Kukupa.app_config['outside-request-forms'][form_name]
    tl_names = tl_names.map {|k, v| [k.to_sym, v&.to_sym]}.to_h
    Kukupa.app_config['outside-request-forms']['default'].each do |k, v|
      tl_names[k.to_sym] ||= v&.to_sym
    end

    ###
    # TL overrides
    ###

    override_tl = override_tl_h = Kukupa.app_config['outside-request-override-tl'].dup
    if override_tl_h.is_a?(Hash)
      override_tl = ((override_tl_h[form_name] || override_tl_h['default']) || []).dup
    end

    # convert to symbols
    override_tl = override_tl.map do |k, v|
      if v.is_a?(Array)
        v = v.map{|x| x&.to_sym}
      elsif v.is_a?(Hash)
        v = v.map{|xk, xv| [xk.to_sym, xv&.to_sym]}.to_h
      else
        v = v&.to_sym
      end

      [k.to_sym, v]
    end.to_h

    # set defaults if they don't exist in the target hash
    if override_tl_h.is_a?(Hash)
      override_tl_h['default'].each do |k, v|
        override_tl[k.to_sym] ||= v&.to_sym
      end
    end

    ###
    # Extra metadata fields
    ###

    extra_metadata = extra_metadata_h = Kukupa.app_config['outside-request-extra-metadata'].dup
    if extra_metadata_h.is_a?(Hash)
      extra_metadata = ((extra_metadata_h[form_name] || extra_metadata_h['default']) || []).dup
    end

    # convert keys to symbols
    extra_metadata = extra_metadata.map do |em|
      em.map{|k, v| [k.to_sym, v]}.to_h
    end

    ###
    # Request categories
    ###

    categories = categories_h = Kukupa.app_config['outside-request-categories'].dup
    if categories_h.is_a?(Hash)
      categories = ((categories_h[form_name] || categories_h['default']) || []).dup
    end

    ###
    # Request agreements
    ###

    agreements = agreements_h = Kukupa.app_config['outside-request-required-agreements'].dup
    if agreements_h.is_a?(Hash)
      agreements = ((agreements_h[form_name] || agreements_h['default']) || []).dup
    end

    {
      name: form_name,
      tl_names: tl_names,
      override_tl: override_tl,
      extra_metadata: extra_metadata,
      categories: categories,
      agreements: agreements,
    }
  end
end
