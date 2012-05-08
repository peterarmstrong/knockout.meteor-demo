Notes    = new Meteor.Collection "note"
Projects = new Meteor.Collection "project"
Contexts = new Meteor.Collection "context"

reference = (collection, regex, summary)->
  m = summary.match regex
  if m
    upsert = (query)->
      id = collection.findOne(query)?._id
      if id then id else collection.insert(query)
    upsert name:m[1]

Meteor.startup ->
  entity_mapper = (collection, opts)->
    _mapper =
      create:(e)->
        _.extend ko.mapping.fromJS(e.data), opts?(e),
          update: ->
            this.mtime? Date.now()
            collection.update {_id:this._id()}, ko.mapping.toJS this

  note_acts = (args)->
    prop = (colle_name, id_name, pname)-> ko.utils.unwrapObservable (_.find viewModel[colle_name](), (e)-> e._id() is args.data[id_name])?[pname] or ""
    acts =
      complete:(note)-> Notes.update {_id:note._id()}, _.extend ko.mapping.toJS(note), {completed:true}
      trash:(note)-> Notes.update {_id:note._id()}, _.extend ko.mapping.toJS(note), {trashed:true}
      project_name: ko.computed -> prop "projects", "project_id", "name"
      context_name: ko.computed -> prop "contexts", "context_id", "name"

  viewModel =
    note:
      summary: ko.observable ""
      created: ->
        note = _.extend (ko.mapping.toJS viewModel.note), {completed:false, trashed:false, ctime:Date.now(), mtime:null}
        note["project_id"] = reference Projects, "#([a-zA-Z0-9_\-]+)", note.summary
        note["context_id"] = reference Contexts, "@([a-zA-Z0-9_\-]+)", note.summary
        Notes.insert note
        viewModel.note.summary ""
    filters:
      trashed: ko.observable false
      completed: ko.observable false
      clear: ->
        viewModel.filters.trashed false
        viewModel.filters.completed false
        _.each _.flatten([viewModel.projects(), viewModel.contexts()]), (e)-> e.filtered false
    projects: ko.meteor.find(Projects, {}, mapping:entity_mapper(Projects, (->{filtered:ko.observable false})))
    contexts: ko.meteor.find(Contexts, {}, mapping:entity_mapper(Contexts, (->{filtered:ko.observable false})))

  viewModel = _.extend viewModel,
    notes: ko.dependentObservable ->
      query =
        completed:viewModel.filters.completed()
        trashed:viewModel.filters.trashed()
        project_id: $in:_.compact viewModel.projects().map((e)->e.filtered() and e._id())
        context_id: $in:_.compact viewModel.contexts().map((e)->e.filtered() and e._id())
      delete query.context_id if query.context_id.$in.length is 0
      delete query.project_id if query.project_id.$in.length is 0
      ko.meteor.find(Notes, query, mapping:entity_mapper Notes, note_acts)()
  
  find_entity = (src)-> $(src).parents(".entity:eq(0)").data().tmplItem.data

  ko.applyBindings viewModel, document.getElementsByTagName("body")[0]
  
  $("body").on "change", ".entity .attr", (p)-> find_entity($(p.srcElement)).update()
  jwerty.key "enter", viewModel.note.created, "#note_summary"
