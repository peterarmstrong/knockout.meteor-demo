Notes    = new Meteor.Collection "note"
Projects = new Meteor.Collection "project"
Contexts = new Meteor.Collection "context"

ref_id = (collection, regex, summary)->
  m = summary.match regex
  if m
    upsert = (query)->
      id = collection.findOne(query)?._id
      if id then id else collection.insert(query)
    upsert name:m[1]

entity_mapper = (collection, opts)->
  _mapper =
    create:(e)->
      data = _.extend {ctime:Date.now(), mtime:null}, e.data
      _.extend ko.mapping.fromJS(data), opts?(e),
        update: ->
          this.mtime Date.now()
          collection.update {_id:this._id()}, ko.mapping.toJS this

Meteor.startup ->
  tagging = (collection)-> ko.meteor.find(collection, {}, mapping:entity_mapper(collection, (->{filtered:ko.observable false})))
  independentModel =
    note:
      summary: ko.observable ""
      created: ->
        note = _.extend (ko.mapping.toJS independentModel.note), {completed:false, trashed:false}
        note["project_id"] = ref_id Projects, "#([a-zA-Z0-9_\-]+)", note.summary
        note["context_id"] = ref_id Contexts, "@([a-zA-Z0-9_\-]+)", note.summary
        Notes.insert note
        independentModel.note.summary ""
    projects: tagging Projects
    contexts: tagging Contexts

  filtered_tags = (name)-> _.compact independentModel[name]().map((e)->e.filtered() and e._id())
  filterModel =
    filters:
      trashed  : ko.observable false
      completed: ko.observable false
      projects : -> filtered_tags 'projects'
      contexts : -> filtered_tags 'contexts'
      clear: ->
        filterModel.filters.trashed false
        filterModel.filters.completed false
        _.each _.flatten([independentModel.projects(), independentModel.contexts()]), (e)-> e.filtered false

  noteListModel =
    notes: ko.dependentObservable ->
      note_acts = (args)->
        prop = (colle_name, id_name, pname)-> ko.utils.unwrapObservable (_.find independentModel[colle_name](), (e)-> e._id() is args.data[id_name])?[pname] or ""
        acts =
          complete:(note)-> Notes.update {_id:note._id()}, _.extend ko.mapping.toJS(note), {completed:true}
          trash:(note)-> Notes.update {_id:note._id()}, _.extend ko.mapping.toJS(note), {trashed:true}
          project_name: ko.computed -> prop "projects", "project_id", "name"
          context_name: ko.computed -> prop "contexts", "context_id", "name"
      query =
        completed : filterModel.filters.completed()
        trashed   : filterModel.filters.trashed()
        project_id: $in:filterModel.filters.projects()
        context_id: $in:filterModel.filters.contexts()
      delete query.context_id if query.context_id.$in.length is 0
      delete query.project_id if query.project_id.$in.length is 0
      ko.meteor.find(Notes, query, mapping:entity_mapper Notes, note_acts)()
  
  find_entity = (src)-> $(src).parents(".entity:eq(0)").data().tmplItem.data

  viewModel = _.extend independentModel, filterModel, noteListModel
  ko.applyBindings viewModel, document.getElementsByTagName("body")[0]
  
  $("body").on "change", ".entity .attr", (p)-> find_entity($(p.srcElement)).update()
  jwerty.key "enter", viewModel.note.created, "#note_summary"
