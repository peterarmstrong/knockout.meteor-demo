Notes    = new Meteor.Collection "note"
Projects = new Meteor.Collection "project"
Contexts = new Meteor.Collection "context"

## Set up sample project and context
Meteor.startup ->
  _.each [
      {name:"Ramen", icon:""}
      {name:"Soba", icon:""}
      {name:"Hiyamugi", icon:""}
  ], (e)->
    it = Projects.findOne {name:e.name}
    return it if it
    Projects.insert e

  _.each [
      {name:"Home", icon:"icon-home"}
      {name:"Office", icon:"icon-briefcase"}
      {name:"Errands", icon:"icon-fire"}
  ], (e)->
    it = Contexts.findOne name:e.name
    return it if it
    Contexts.insert e
