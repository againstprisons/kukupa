module Kukupa::Helpers::CaseViewHelpers
  def get_tasks(c, opts = {})
    c = c.id if c.respond_to?(:id)
    advocates = {}

    ds = Kukupa::Models::CaseTask.where(case: c)
    ds = ds.where(completion: nil) unless opts[:include_complete]

    tasks = ds.map do |ct|
      advocates = case_populate_advocate(advocates, ct.author)
      advocates = case_populate_advocate(advocates, ct.assigned_to)

      {
        id: "CaseTask[#{ct.id}]",
        url: url("/case/#{c}/task/#{ct.id}"),
        anchor: ct.anchor,
        creation: ct.creation,
        completion: ct.completion,
        content: ct.decrypt(:content),
        author: advocates[ct.author.to_s],
        assigned_to: advocates[ct.assigned_to.to_s],
      }
    end

    complete = tasks.select { |x| x[:completion] != nil }
    tasks.reject! { |x| x[:completion] != nil }
    tasks.sort! { |a, b| b[:creation] <=> a[:creation] }
    complete.sort! { |a, b| b[:completion] <=> a[:completion] }

    [tasks, complete].flatten
  end

  def get_renderables(c, opts = {})
    c = c.id if c.respond_to?(:id)
    items = []

    # set default options
    opts = {
      page: 1,
      pagination: false,
      pagination_items: 25,
      include_updates: false,
      renderable_opts: {},
    }.merge(opts)

    # sanity check
    opts[:page] = 1 if opts[:page] < 1
    opts[:pagination_items] = 25 if opts[:pagination_items] < 1

    ###
    # Case notes
    ###

    notes = Kukupa::Models::CaseNote
      .select(:id, :case, :creation)
      .where(case: c)
      .reverse(:creation)
      .map { |x| {klass: Kukupa::Models::CaseNote, id: x.id, creation: x.creation} }

    items << notes
    if opts[:include_updates]
      items << notes.map do |cn|
        Kukupa::Models::CaseNoteUpdate
          .select(:id, :note, :creation)
          .where(note: cn[:id])
          .reverse(:creation)
          .map { |x| {klass: Kukupa::Models::CaseNoteUpdate, id: x.id, creation: x.creation} }
      end
    end

    ###
    # Case spends
    ###

    spends = Kukupa::Models::CaseSpend
      .select(:id, :case, :creation)
      .where(case: c)
      .reverse(:creation)
      .map { |x| {klass: Kukupa::Models::CaseSpend, id: x.id, creation: x.creation} }

    items << spends
    if opts[:include_updates]
      items << spends.map do |cs|
        Kukupa::Models::CaseSpendUpdate
          .select(:id, :spend, :creation)
          .where(spend: cs[:id])
          .reverse(:creation)
          .map { |x| {klass: Kukupa::Models::CaseSpendUpdate, id: x.id, creation: x.creation} }
      end
    end

    ###
    # Case tasks
    ###

    tasks = Kukupa::Models::CaseTask
      .select(:id, :case, :creation)
      .where(case: c)
      .reverse(:creation)
      .map { |x| {klass: Kukupa::Models::CaseTask, id: x.id, creation: x.creation} }

    items << tasks
    if opts[:include_updates]
      items << tasks.map do |ct|
        Kukupa::Models::CaseTaskUpdate
          .select(:id, :task, :creation)
          .where(task: ct[:id])
          .reverse(:creation)
          .map { |x| {klass: Kukupa::Models::CaseTaskUpdate, id: x.id, creation: x.creation} }
      end
    end

    ###
    # Correspondence
    ###

    items << Kukupa::Models::CaseCorrespondence
      .select(:id, :case, :creation)
      .where(case: c)
      .reverse(:creation)
      .map { |x| {klass: Kukupa::Models::CaseCorrespondence, id: x.id, creation: x.creation} }

    ###
    # Array flattening and pagination
    ###

    items = items.flatten.compact.sort { |a, b| b[:creation] <=> a[:creation] }

    if opts[:pagination]
      offset_start = opts[:pagination_items] * (opts[:page] - 1)
      offset_finish = opts[:pagination_items] * opts[:page]

      items = items[offset_start .. offset_finish]
    end

    ###
    # Call renderable generation methods and sort by creation
    ### 

    renderables = items.map do |x|
      item = x[:klass].send(:[], x[:id])
      item.renderables(opts[:renderable_opts])
    end

    renderables = renderables
      .flatten
      .compact
      .sort { |a, b| b[:creation] <=> a[:creation] }

    ###
    # Item value post-processing
    #
    # If a value of the renderable hash is an array, and the first item in
    # that array is one of the known post-process types, we take the last
    # item in the array as the value, and post-process that.
    #
    # Known post-process types are:
    #   * `:url` - Passes the value through the Sinatra `url()` method
    #   * `:user` - Gets user information using `case_populate_advocate`
    ###

    advocates = {}
    do_process = Proc.new do |value|
      if value.is_a?(Array)
        k_first = value.first
        k_value = value.last

        # Process URLs
        if k_first == :url
          value = url(k_value)

        # Populate advocate information
        elsif k_first == :user
          advocates = case_populate_advocate(advocates, k_value.to_i)
          value = advocates[k_value.to_s]
        end
      end

      value
    end

    # This is a mess. But it works!
    renderables.each do |rb|
      rb.each do |k, v|
        if k == :actions
          v.each_index do |i|
            rb[k][i].each do |ik, iv|
              rb[k][i][ik] = do_process[iv]
            end
          end

        elsif v.is_a? Hash
          v.each do |ik, iv|
            rb[k][ik] = do_process[iv]
          end

        else
          rb[k] = do_process[v]
        end
      end
    end

    ###
    # And return the result!
    ###

    renderables
  end
end
