trim = (html) =>
  html = html.replace />\s+/g, '>'
  html = html.replace /\s+</g, '<'
  html.trim()

class MainComponent extends BlazeComponent
  @calls: []

  template: ->
    assert not Tracker.active

    # To test when name of the component mismatches the template name. Template name should have precedence.
    'MainComponent2'

  foobar: ->
    "#{@componentName()}/MainComponent.foobar/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

  foobar2: ->
    "#{@componentName()}/MainComponent.foobar2/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

  foobar3: ->
    "#{@componentName()}/MainComponent.foobar3/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

  isMainComponent: ->
    @constructor is MainComponent

  onClick: (event) ->
    assert not Tracker.active

    @constructor.calls.push [@componentName(), 'MainComponent.onClick', @data(), @currentData(), @currentComponent().componentName()]

  events: ->
    assert not Tracker.active

    [
      'click': @onClick
    ]

  onCreated: ->
    self = @
    # To test that a computation is bound to the component.
    @autorun (computation) ->
      assert.equal @, self

BlazeComponent.register 'MainComponent', MainComponent

# Template should match registered name.
class FooComponent extends BlazeComponent

BlazeComponent.register 'FooComponent', FooComponent

class SelfRegisterComponent extends BlazeComponent
  # Alternative way of registering components.
  @register 'SelfRegisterComponent'

class SubComponent extends MainComponent
  @calls: []

  foobar: ->
    "#{@componentName()}/SubComponent.foobar/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

  foobar2: ->
    "#{@componentName()}/SubComponent.foobar2/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

  # We on purpose do not override foobar3.

  onClick: (event) ->
    @constructor.calls.push [@componentName(), 'SubComponent.onClick', @data(), @currentData(), @currentComponent().componentName()]

BlazeComponent.register 'SubComponent', SubComponent

class UnregisteredComponent extends SubComponent
  foobar: ->
    "#{@componentName()}/UnregisteredComponent.foobar/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

  foobar2: ->
    "#{@componentName()}/UnregisteredComponent.foobar2/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

# Name has to be set manually.
UnregisteredComponent.componentName 'UnregisteredComponent'

class SelfNameUnregisteredComponent extends UnregisteredComponent
  # Alternative way of setting the name manually.
  @componentName 'SelfNameUnregisteredComponent'

  # We do not extend any helper on purpose. So they should all use "UnregisteredComponent".

class AnimatedListComponent extends BlazeComponent
  @calls: []

  template: ->
    assert not Tracker.active

    'AnimatedListComponent'

  onCreated: ->
    assert not Tracker.active

    # To test inserts, moves, and removals.
    @_list = new ReactiveField [1, 2, 3, 4, 5]
    @_handle = Meteor.setInterval =>
      list = @_list()

      # Moves the last number to the first place.
      list = [list[4]].concat list[0...4]

      # Removes the smallest number.
      list = _.without list, _.min list

      # Adds one more number, one larger than the current largest.
      list = list.concat [_.max(list) + 1]

      @_list list
    , 1000 # ms

  onDestroyed: ->
    assert not Tracker.active

    Meteor.clearInterval @_handle

  list: ->
    _id: i for i in @_list()

  insertDOMElement: (parent, node, before) ->
    assert not Tracker.active

    @constructor.calls.push ['insertDOMElement', @componentName(), trim(parent.outerHTML), trim(node.outerHTML), trim(before?.outerHTML or '')]
    super arguments...

  moveDOMElement: (parent, node, before) ->
    assert not Tracker.active

    @constructor.calls.push ['moveDOMElement', @componentName(), trim(parent.outerHTML), trim(node.outerHTML), trim(before?.outerHTML or '')]
    super arguments...

  removeDOMElement: (parent, node) ->
    assert not Tracker.active

    @constructor.calls.push ['removeDOMElement', @componentName(), trim(parent.outerHTML), trim(node.outerHTML)]
    super arguments...

BlazeComponent.register 'AnimatedListComponent', AnimatedListComponent

class DummyComponent extends BlazeComponent
  @register 'DummyComponent'

class ArgumentsComponent extends BlazeComponent
  @calls: []
  @constructorStateChanges: []
  @onCreatedStateChanges: []

  template: ->
    assert not Tracker.active

    'ArgumentsComponent'

  constructor: ->
    super arguments...
    assert not Tracker.active

    @constructor.calls.push arguments[0]
    @arguments = arguments

    @componentId = Random.id()

    @handles = []

    @collectStateChanges @constructor.constructorStateChanges

  onCreated: ->
    assert not Tracker.active

    super arguments...

    @collectStateChanges @constructor.onCreatedStateChanges

  collectStateChanges: (output) ->
    output.push
      componentId: @componentId
      view: Blaze.currentView
      templateInstance: Template.instance()

    for method in ['isCreated', 'isRendered', 'isDestroyed', 'data', 'currentData', 'component', 'currentComponent', 'firstNode', 'lastNode', 'subscriptionsReady']
      do (method) =>
        @handles.push Tracker.autorun (computation) =>
          data =
            componentId: @componentId
          data[method] = @[method]()

          output.push data

    @handles.push Tracker.autorun (computation) =>
      output.push
        componentId: @componentId
        find: @find('*')

    @handles.push Tracker.autorun (computation) =>
      output.push
        componentId: @componentId
        findAll: @findAll('*')

    @handles.push Tracker.autorun (computation) =>
      output.push
        componentId: @componentId
        $: @$('*')

  onDestroyed: ->
    assert not Tracker.active

    super arguments...

    Tracker.afterFlush =>
      while handle = @handles.pop()
        handle.stop()

  dataContext: ->
    EJSON.stringify @data()

  currentDataContext: ->
    EJSON.stringify @currentData()

  constructorArguments: ->
    EJSON.stringify @arguments

  parentDataContext: ->
    # We would like to make sure data context hierarchy
    # is without intermediate arguments data context.
    EJSON.stringify Template.parentData()

BlazeComponent.register 'ArgumentsComponent', ArgumentsComponent

class MyNamespace

class MyNamespace.Foo

class MyNamespace.Foo.ArgumentsComponent extends ArgumentsComponent
  @register 'MyNamespace.Foo.ArgumentsComponent'

  template: ->
    assert not Tracker.active

    # We could simply use "ArgumentsComponent" here and not have to copy the
    # template, but we want to test if a template name with dots works.
    'MyNamespace.Foo.ArgumentsComponent'

# We want to test if a component with the same name as the namespace can coexist.
class OurNamespace extends ArgumentsComponent
  @register 'OurNamespace'

  template: ->
    assert not Tracker.active

    # We could simply use "ArgumentsComponent" here and not have to copy the
    # template, but we want to test if a template name with dots works.
    'OurNamespace'

class OurNamespace.ArgumentsComponent extends ArgumentsComponent
  @register 'OurNamespace.ArgumentsComponent'

  template: ->
    assert not Tracker.active

    # We could simply use "ArgumentsComponent" here and not have to copy the
    # template, but we want to test if a template name with dots works.
    'OurNamespace.ArgumentsComponent'

reactiveContext = new ReactiveField {}
reactiveArguments = new ReactiveField {}

class ArgumentsTestComponent extends BlazeComponent
  @register 'ArgumentsTestComponent'

  reactiveContext: ->
    reactiveContext()

  reactiveArguments: ->
    reactiveArguments()

Template.namespacedArgumentsTestTemplate.helpers
  reactiveContext: ->
    reactiveContext()

  reactiveArguments: ->
    reactiveArguments()

Template.ourNamespacedArgumentsTestTemplate.helpers
  reactiveContext: ->
    reactiveContext()

  reactiveArguments: ->
    reactiveArguments()

Template.ourNamespaceComponentArgumentsTestTemplate.helpers
  reactiveContext: ->
    reactiveContext()

  reactiveArguments: ->
    reactiveArguments()

class ExistingClassHierarchyBase
  foobar: ->
    "#{@componentName()}/ExistingClassHierarchyBase.foobar/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

  foobar2: ->
    "#{@componentName()}/ExistingClassHierarchyBase.foobar2/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

  foobar3: ->
    "#{@componentName()}/ExistingClassHierarchyBase.foobar3/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

class ExistingClassHierarchyChild extends ExistingClassHierarchyBase

class ExistingClassHierarchyBaseComponent extends ExistingClassHierarchyChild

for property, value of BlazeComponent when property not in ['__super__']
  ExistingClassHierarchyBaseComponent[property] = value
for property, value of (BlazeComponent::) when property not in ['constructor']
  ExistingClassHierarchyBaseComponent::[property] = value

class ExistingClassHierarchyComponent extends ExistingClassHierarchyBaseComponent
  template: ->
    assert not Tracker.active

    'MainComponent2'

  foobar: ->
    "#{@componentName()}/ExistingClassHierarchyComponent.foobar/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

  foobar2: ->
    "#{@componentName()}/ExistingClassHierarchyComponent.foobar2/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

  # We on purpose do not override foobar3.

ExistingClassHierarchyComponent.register 'ExistingClassHierarchyComponent', ExistingClassHierarchyComponent

class FirstMixin extends BlazeComponent
  @calls: []

  foobar: ->
    "#{@component().componentName()}/FirstMixin.foobar/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

  foobar2: ->
    "#{@component().componentName()}/FirstMixin.foobar2/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

  foobar3: ->
    "#{@component().componentName()}/FirstMixin.foobar3/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

  isMainComponent: ->
    @component().constructor is WithMixinsComponent

  onClick: (event) ->
    @constructor.calls.push [@component().componentName(), 'FirstMixin.onClick', @data(), @currentData(), @currentComponent().componentName()]

  events: -> [
    'click': @onClick
  ]

class SecondMixin extends BlazeComponent
  @calls: []

  template: ->
    assert not Tracker.active

    @_template()

  _template: ->
    'MainComponent2'

  foobar: ->
    "#{@component().componentName()}/SecondMixin.foobar/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

  foobar2: ->
    "#{@component().componentName()}/SecondMixin.foobar2/#{EJSON.stringify @data()}/#{EJSON.stringify @currentData()}/#{@currentComponent().componentName()}"

  # We on purpose do not provide foobar3.

  onClick: (event) ->
    @constructor.calls.push [@component().componentName(), 'SecondMixin.onClick', @data(), @currentData(), @currentComponent().componentName()]

  events: ->
    assert not Tracker.active

    [
      'click': @onClick
    ]

  onCreated: ->
    assert not Tracker.active

    # To test if adding a dependency during onCreated will make sure
    # to call onCreated on the added dependency as well.
    @mixinParent().requireMixin DependencyMixin

SecondMixin.componentName 'SecondMixin'

class DependencyMixin extends BlazeComponent
  @calls: []

  onCreated: ->
    assert not Tracker.active

    @constructor.calls.push true

class WithMixinsComponent extends BlazeComponent
  @output: []

  mixins: ->
    assert not Tracker.active

    [SecondMixin, FirstMixin]

  onDestroyed: ->
    firstMixin = @getMixin FirstMixin
    @constructor.output.push @
    @constructor.output.push firstMixin
    @constructor.output.push @getMixin firstMixin
    @constructor.output.push @getMixin @
    @constructor.output.push @getMixin DependencyMixin
    @constructor.output.push @getMixin 'FirstMixin'
    @constructor.output.push @getMixin 'SecondMixin'
    @constructor.output.push @getFirstWith null, 'isMainComponent'
    @constructor.output.push @getFirstWith null, (child, parent) =>
      !!child.constructor.output
    @constructor.output.push @getFirstWith null, (child, parent) =>
      child is parent
    @constructor.output.push @getFirstWith null, (child, parent) =>
      child._template?() is 'MainComponent2'

BlazeComponent.register 'WithMixinsComponent', WithMixinsComponent

class AfterCreateValueComponent extends BlazeComponent
  template: ->
    assert not Tracker.active

    'AfterCreateValueComponent'

  onCreated: ->
    assert not Tracker.active

    @foobar = '42'
    @_foobar = '43'

BlazeComponent.register 'AfterCreateValueComponent', AfterCreateValueComponent

class PostMessageButtonComponent extends BlazeComponent
  onCreated: ->
    assert not Tracker.active

    @color = new ReactiveField "Red"

    $(window).on 'message.buttonComponent', (event) =>
      if color = event.originalEvent.data?.color
        @color color

  onDestroyed: ->
    $(window).off '.buttonComponent'

BlazeComponent.register 'PostMessageButtonComponent', PostMessageButtonComponent

class TableWrapperBlockComponent extends BlazeComponent
  template: ->
    assert not Tracker.active

    'TableWrapperBlockComponent'

  currentDataContext: ->
    EJSON.stringify @currentData()

  parentDataContext: ->
    # We would like to make sure data context hierarchy
    # is without intermediate arguments data context.
    EJSON.stringify Template.parentData()

BlazeComponent.register 'TableWrapperBlockComponent', TableWrapperBlockComponent

Template.testBlockComponent.helpers
  parentDataContext: ->
    # We would like to make sure data context hierarchy
    # is without intermediate arguments data context.
    EJSON.stringify Template.parentData()

  customersDataContext: ->
    customers: [
      name: 'Foo'
      email: 'foo@example.com'
    ]

reactiveChild1 = new ReactiveField false
reactiveChild2 = new ReactiveField false

class ChildComponent extends BlazeComponent
  template: ->
    assert not Tracker.active

    'ChildComponent'

  constructor: (@childName) ->
    super arguments...
    assert not Tracker.active

  onCreated: ->
    assert not Tracker.active

    @domChanged = new ReactiveField 0

  insertDOMElement: (parent, node, before) ->
    assert not Tracker.active

    super arguments...

    @domChanged Tracker.nonreactive =>
      @domChanged() + 1

  moveDOMElement: (parent, node, before) ->
    assert not Tracker.active

    super arguments...

    @domChanged Tracker.nonreactive =>
      @domChanged() + 1

  removeDOMElement: (parent, node) ->
    assert not Tracker.active

    super arguments...

    @domChanged Tracker.nonreactive =>
      @domChanged() + 1

BlazeComponent.register 'ChildComponent', ChildComponent

class ParentComponent extends BlazeComponent
  template: ->
    assert not Tracker.active

    'ParentComponent'

  child1: ->
    reactiveChild1()

  child2: ->
    reactiveChild2()

BlazeComponent.register 'ParentComponent', ParentComponent

class CaseComponent extends BlazeComponent
  @register 'CaseComponent'

  constructor: (kwargs) ->
    super arguments...
    assert not Tracker.active

    @cases = kwargs.hash

  renderCase: ->
    caseComponent = @cases[@data().case]
    return null unless caseComponent
    BlazeComponent.getComponent(caseComponent).renderComponent @

class LeftComponent extends BlazeComponent
  @register 'LeftComponent'

  template: ->
    assert not Tracker.active

    'LeftComponent'

class MiddleComponent extends BlazeComponent
  @register 'MiddleComponent'

  template: ->
    assert not Tracker.active

    'MiddleComponent'

class RightComponent extends BlazeComponent
  @register 'RightComponent'

  template: ->
    assert not Tracker.active

    'RightComponent'

class MyComponent extends BlazeComponent
  @register 'MyComponent'

  mixins: ->
    assert not Tracker.active

    [FirstMixin2, new SecondMixin2 'foobar']

  alternativeName: ->
    @callFirstWith null, 'templateHelper'

  values: ->
    'a' + (@callFirstWith(@, 'values') or '')

class FirstMixinBase extends BlazeComponent
  @calls: []

  templateHelper: ->
    "42"

  extendedHelper: ->
    1

  onClick: ->
    throw new Error() if @values() isnt @valuesPredicton
    @constructor.calls.push true

class FirstMixin2 extends FirstMixinBase
  extendedHelper: ->
    super() + 2

  values: ->
    'b' + (@mixinParent().callFirstWith(@, 'values') or '')

  dataContext: ->
    EJSON.stringify @data()

  events: ->
    assert not Tracker.active

    super.concat
      'click': @onClick

  onCreated: ->
    assert not Tracker.active

    @valuesPredicton = 'bc'

class SecondMixin2
  constructor: (@name) ->
    assert not Tracker.active

  mixinParent: (mixinParent) ->
    @_mixinParent = mixinParent if mixinParent
    @_mixinParent

  values: ->
    'c' + (@mixinParent().callFirstWith(@, 'values') or '')

# Example from the README.
class ExampleComponent extends BlazeComponent
  @register 'ExampleComponent'

  onCreated: ->
    assert not Tracker.active

    super arguments...
    @counter = new ReactiveField 0

  events: ->
    assert not Tracker.active

    super.concat
      'click .increment': @onClick

  onClick: (event) ->
    @counter @counter() + 1

  customHelper: ->
    if @counter() > 10
      "Too many times"
    else if @counter() is 10
      "Just enough"
    else
      "Click more"

class OuterComponent extends BlazeComponent
  @register 'OuterComponent'

  @calls: []

  template: ->
    assert not Tracker.active

    'OuterComponent'

  onCreated: ->
    assert not Tracker.active

    OuterComponent.calls.push 'OuterComponent onCreated'

  onRendered: ->
    assert not Tracker.active

    OuterComponent.calls.push 'OuterComponent onRendered'

  onDestroyed: ->
    assert not Tracker.active

    OuterComponent.calls.push 'OuterComponent onDestroyed'

class InnerComponent extends BlazeComponent
  @register 'InnerComponent'

  template: ->
    assert not Tracker.active

    'InnerComponent'

  onCreated: ->
    assert not Tracker.active

    OuterComponent.calls.push 'InnerComponent onCreated'

  onRendered: ->
    assert not Tracker.active

    OuterComponent.calls.push 'InnerComponent onRendered'

  onDestroyed: ->
    assert not Tracker.active

    OuterComponent.calls.push 'InnerComponent onDestroyed'

class TemplateDynamicTestComponent extends MainComponent
  @register 'TemplateDynamicTestComponent'

  @calls: []

  template: ->
    assert not Tracker.active

    'TemplateDynamicTestComponent'

  isMainComponent: ->
    @constructor is TemplateDynamicTestComponent

class ExtraTableWrapperBlockComponent extends BlazeComponent
  @register 'ExtraTableWrapperBlockComponent'

class TestBlockComponent extends BlazeComponent
  @register 'TestBlockComponent'

  nameFromComponent: ->
    "Works"

  renderRow: ->
    BlazeComponent.getComponent('RowComponent').renderComponent @currentComponent()

class RowComponent extends BlazeComponent
  @register 'RowComponent'

class FootComponent extends BlazeComponent
  @register 'FootComponent'

class CaptionComponent extends BlazeComponent
  @register 'CaptionComponent'

class RenderRowComponent extends BlazeComponent
  @register 'RenderRowComponent'

  parentComponentRenderRow: ->
    @parentComponent().parentComponent().renderRow()

class TestingComponentDebug extends BlazeComponentDebug
  @structure: {}

  stack = []

  @lastElement: (structure) ->
    return structure if 'children' not of structure

    stack[stack.length - 1] = structure.children
    @lastElement structure.children[structure.children.length - 1]

  @startComponent: (component) ->
    stack.push null
    element = @lastElement @structure

    element.component = component.componentName()
    element.data = component.data()
    element.children = [{}]

  @endComponent: (component) ->
    # Only the top-level stack element stays null and is not set to a children array.
    stack[stack.length - 1].push {} if stack.length > 1
    stack.pop()

  @startMarkedComponent: (component) ->
    @startComponent component

  @endMarkedComponent: (component) ->
    @endComponent component

class LexicalArgumentsComponent extends BlazeComponent
  @register 'LexicalArgumentsComponent'

  rowOfCurrentData: ->
    EJSON.stringify @currentData()

  rowOfFooAndIndex: ->
    "#{EJSON.stringify @currentData 'foo'}/#{@currentData '@index'}"

mainComponent3Calls = []

Template.mainComponent3.events
  'click': (event, template) ->
    assert.equal Template.instance(), template
    assert not Tracker.active
    if Template.instance().component
      template = Template.instance().component.constructor
    else
      template = Template.instance().view.template

    mainComponent3Calls.push [template, 'mainComponent3.onClick', @, Template.currentData(), Blaze.getData(Template.instance().view), Template.parentData()]

Template.mainComponent3.helpers
  foobar: ->
    if Template.instance().component
      assert.equal Template.instance().component.constructor, MainComponent3
    else
      assert.equal Template.instance().view.template, Template.mainComponent3

    "mainComponent3.foobar/#{EJSON.stringify @}/#{EJSON.stringify Template.currentData()}/#{EJSON.stringify Blaze.getData(Template.instance().view)}/#{EJSON.stringify Template.parentData()}"

  foobar2: ->
    if Template.instance().component
      assert.equal Template.instance().component.constructor, MainComponent3
    else
      assert.equal Template.instance().view.template, Template.mainComponent3

    "mainComponent3.foobar2/#{EJSON.stringify @}/#{EJSON.stringify Template.currentData()}/#{EJSON.stringify Blaze.getData(Template.instance().view)}/#{EJSON.stringify Template.parentData()}"

  foobar3: ->
    if Template.instance().component
      assert.equal Template.instance().component.constructor, MainComponent3
    else
      assert.equal Template.instance().view.template, Template.mainComponent3

    "mainComponent3.foobar3/#{EJSON.stringify @}/#{EJSON.stringify Template.currentData()}/#{EJSON.stringify Blaze.getData(Template.instance().view)}/#{EJSON.stringify Template.parentData()}"

Template.mainComponent3.onCreated ->
  assert not Tracker.active
  assert.equal Template.instance(), @
  if Template.instance().component
    template = Template.instance().component.constructor
  else
    template = Template.instance().view.template

  mainComponent3Calls.push [template, 'mainComponent3.onCreated', Template.currentData(), Blaze.getData(Template.instance().view), Template.parentData()]

Template.mainComponent3.onRendered ->
  assert not Tracker.active
  assert.equal Template.instance(), @
  if Template.instance().component
    template = Template.instance().component.constructor
  else
    template = Template.instance().view.template

  mainComponent3Calls.push [template, 'mainComponent3.onRendered', Template.currentData(), Blaze.getData(Template.instance().view), Template.parentData()]

Template.mainComponent3.onDestroyed ->
  assert not Tracker.active
  assert.equal Template.instance(), @
  if Template.instance().component
    template = Template.instance().component.constructor
  else
    template = Template.instance().view.template

  mainComponent3Calls.push [template, 'mainComponent3.onDestroyed', Template.currentData(), Blaze.getData(Template.instance().view), Template.parentData()]

class MainComponent3 extends BlazeComponent
  @register 'MainComponent3'

  template: ->
    'mainComponent3'

  foobar: ->
    # An ugly way to extend a base template helper.
    helper = @_componentInternals.templateBase.__helpers.get 'foobar'

    # Blaze template helpers expect current data context bound to "this".
    result = helper.call @currentData()

    'super:' + result

reactiveArguments = new ReactiveField null

class InlineEventsComponent extends BlazeComponent
  @calls: []

  @register 'InlineEventsComponent'

  onButton1Click: (event) ->
    @constructor.calls.push [@componentName(), 'InlineEventsComponent.onButton1Click', @data(), @currentData(), @currentComponent().componentName()]

  onButton2Click: (event) ->
    @constructor.calls.push [@componentName(), 'InlineEventsComponent.onButton2Click', @data(), @currentData(), @currentComponent().componentName()]

  onClick1Extra: (event) ->
    @constructor.calls.push [@componentName(), 'InlineEventsComponent.onClick1Extra', @data(), @currentData(), @currentComponent().componentName()]

  onButton3Click: (event, args...) ->
    @constructor.calls.push [@componentName(), 'InlineEventsComponent.onButton3Click', @data(), @currentData(), @currentComponent().componentName()].concat args

  onButton4Click: (event, args...) ->
    @constructor.calls.push [@componentName(), 'InlineEventsComponent.onButton4Click', @data(), @currentData(), @currentComponent().componentName()].concat args

  dynamicArgument: ->
    reactiveArguments()

  onChange: (event) ->
    @constructor.calls.push [@componentName(), 'InlineEventsComponent.onChange', @data(), @currentData(), @currentComponent().componentName()]

  onTextClick: (event) ->
    @constructor.calls.push [@componentName(), 'InlineEventsComponent.onTextClick', @data(), @currentData(), @currentComponent().componentName()]

  extraArgs1: (event) ->
    @constructor.calls.push [@componentName(), 'InlineEventsComponent.extraArgs1', @data(), @currentData(), @currentComponent().componentName()]

  extraArgs2: (event) ->
    @constructor.calls.push [@componentName(), 'InlineEventsComponent.extraArgs2', @data(), @currentData(), @currentComponent().componentName()]

  extraArgs: ->
    title: "Foobar"
    onClick: [
      @extraArgs1
    ,
      @extraArgs2
    ]

class InvalidInlineEventsComponent extends BlazeComponent
  @register 'InvalidInlineEventsComponent'

class LevelOneComponent extends BlazeComponent
  @register 'LevelOneComponent'

class LevelTwoComponent extends BlazeComponent
  @children: []

  @register 'LevelTwoComponent'

  onCreated: ->
    super arguments...

    @autorun =>
      @constructor.children.push all: @childComponents().length
    @autorun =>
      @constructor.children.push topValue: @childComponentsWith(topValue: 41).length
    @autorun =>
      @constructor.children.push hasValue: @childComponentsWith(hasValue: 42).length
    @autorun =>
      @constructor.children.push hasNoValue: @childComponentsWith(hasNoValue: 43).length

class LevelOneMixin extends BlazeComponent
  mixins: ->
    [LevelTwoMixin]

  # This one should be resolved in the template.
  hasValue: ->
    42

class LevelTwoMixin extends BlazeComponent
  # This one should not be resolved in the template.
  hasNoValue: ->
    43

class ComponentWithNestedMixins extends BlazeComponent
  @register 'ComponentWithNestedMixins'

  mixins: ->
    [LevelOneMixin]

  topValue: ->
    41

class BasicTestCase extends ClassyTestCase
  @testName: 'blaze-components - basic'

  FOO_COMPONENT_CONTENT = ->
    """
      <p>Other component: FooComponent</p>
      <button>Foo2</button>
      <p></p>
      <button>Foo3</button>
      <p></p>
      <p></p>
    """

  COMPONENT_CONTENT = (componentName, helperComponentName, mainComponent) ->
    helperComponentName ?= componentName
    mainComponent ?= 'MainComponent'

    """
      <p>Main component: #{componentName}</p>
      <button>Foo1</button>
      <p>#{componentName}/#{helperComponentName}.foobar/{"top":"42"}/{"top":"42"}/#{componentName}</p>
      <button>Foo2</button>
      <p>#{componentName}/#{helperComponentName}.foobar2/{"top":"42"}/{"a":"1","b":"2"}/#{componentName}</p>
      <p>#{componentName}/#{mainComponent}.foobar3/{"top":"42"}/{"top":"42"}/#{componentName}</p>
      <p>Subtemplate</p>
      <button>Foo1</button>
      <p>#{componentName}/#{helperComponentName}.foobar/{"top":"42"}/{"top":"42"}/#{componentName}</p>
      <button>Foo2</button>
      <p>#{componentName}/#{helperComponentName}.foobar2/{"top":"42"}/{"a":"3","b":"4"}/#{componentName}</p>
      <p>#{componentName}/#{mainComponent}.foobar3/{"top":"42"}/{"top":"42"}/#{componentName}</p>
      #{FOO_COMPONENT_CONTENT()}
    """

  TEST_BLOCK_COMPONENT_CONTENT = ->
    """
      <h2>Names and emails and components (CaptionComponent/CaptionComponent/CaptionComponent)</h2>
      <h3 class="insideBlockHelperTemplate">(ExtraTableWrapperBlockComponent/ExtraTableWrapperBlockComponent/ExtraTableWrapperBlockComponent)</h3>
      <table>
        <thead>
          <tr>
            <th>Name</th>
            <th class="insideBlockHelper">Email</th>
            <th>Component (ExtraTableWrapperBlockComponent/ExtraTableWrapperBlockComponent/ExtraTableWrapperBlockComponent)</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Foo</td>
            <td class="insideContent">foo@example.com</td>
            <td>TestBlockComponent/TestBlockComponent/ExtraTableWrapperBlockComponent</td>
          </tr>
          <tr>
            <td>Bar</td>
            <td class="insideContentComponent">bar@example.com</td>
            <td>RowComponent/RowComponent/RowComponent</td>
          </tr>
          <tr>
            <td>Baz</td>
            <td class="insideContentComponent">baz@example.com</td>
            <td>RowComponent/RowComponent/RowComponent</td>
          </tr>
          <tr>
            <td>Works</td>
            <td class="insideContentComponent">nameFromComponent1@example.com</td>
            <td>RowComponent/RowComponent/RowComponent</td>
          </tr>
          <tr>
            <td>Bac</td>
            <td class="insideContentComponent">bac@example.com</td>
            <td>RowComponent/RowComponent/RowComponent</td>
          </tr>
          <tr>
            <td>Works</td>
            <td class="insideContentComponent">nameFromComponent2@example.com</td>
            <td>RowComponent/RowComponent/RowComponent</td>
          </tr>
          <tr>
            <td>Works</td>
            <td class="insideContentComponent">nameFromComponent3@example.com</td>
            <td>RowComponent/RowComponent/RowComponent</td>
          </tr>
          <tr>
            <td>Bam</td>
            <td class="insideContentComponent">bam@example.com</td>
            <td>RowComponent/RowComponent/RowComponent</td>
          </tr>
          <tr>
            <td>Bav</td>
            <td class="insideContentComponent">bav@example.com</td>
            <td>RowComponent/RowComponent/RowComponent</td>
          </tr>
          <tr>
            <td>Bak</td>
            <td class="insideContentComponent">bak@example.com</td>
            <td>RowComponent/RowComponent/RowComponent</td>
          </tr>
          <tr>
            <td>Bal</td>
            <td class="insideContentComponent">bal@example.com</td>
            <td>RowComponent/RowComponent/RowComponent</td>
          </tr>
        </tbody>
        <tfoot>
          <tr>
            <th>Name</th>
            <th class="insideBlockHelperComponent">Email</th>
            <th>Component (FootComponent/FootComponent/FootComponent)</th>
          </tr>
        </tfoot>
      </table>
    """

  TEST_BLOCK_COMPONENT_STRUCTURE = ->
    component: 'TestBlockComponent'
    data: {top: '42'}
    children: [
      component: 'ExtraTableWrapperBlockComponent'
      data: {block: '43'}
      children: [
        component: 'CaptionComponent'
        data: {block: '43'}
        children: [{}]
      ,
        component: 'RowComponent'
        data: {name: 'Bar', email: 'bar@example.com'}
        children: [{}]
      ,
        component: 'RowComponent'
        data: {name: 'Baz', email: 'baz@example.com'}
        children: [{}]
      ,
        component: 'RowComponent'
        data: {name: 'Works', email: 'nameFromComponent1@example.com'}
        children: [{}]
      ,
        component: 'RowComponent'
        data: {name: 'Bac', email: 'bac@example.com'}
        children: [{}]
      ,
        component: 'RowComponent'
        data: {name: 'Works', email: 'nameFromComponent2@example.com'}
        children: [{}]
      ,
        component: 'RowComponent'
        data: {name: 'Works', email: 'nameFromComponent3@example.com'}
        children: [{}]
      ,
        component: 'RowComponent'
        data: {name: 'Bam', email: 'bam@example.com'}
        children: [{}]
      ,
        component: 'RowComponent'
        data: {name: 'Bav', email: 'bav@example.com'}
        children: [{}]
      ,
        component: 'RenderRowComponent'
        data: {top: '42'}
        children: [
          component: 'RowComponent'
          data: {name: 'Bak', email: 'bak@example.com'}
          children: [{}]
        ,
          component: 'RowComponent'
          data: {name: 'Bal', email: 'bal@example.com'}
          children: [{}]
        ,
          {}
        ]
      ,
        component: 'FootComponent'
        data: {block: '43'}
        children: [{}]
      ,
        {}
      ]
    ,
      {}
    ]

  testComponents: ->
    output = BlazeComponent.getComponent('MainComponent').renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim """
      #{COMPONENT_CONTENT 'MainComponent'}
      <hr>
      #{COMPONENT_CONTENT 'SubComponent'}
    """

    output = new (BlazeComponent.getComponent('MainComponent'))().renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim """
      #{COMPONENT_CONTENT 'MainComponent'}
      <hr>
      #{COMPONENT_CONTENT 'SubComponent'}
    """

    output = BlazeComponent.getComponent('FooComponent').renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim FOO_COMPONENT_CONTENT()

    output = new (BlazeComponent.getComponent('FooComponent'))().renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim FOO_COMPONENT_CONTENT()

    output = BlazeComponent.getComponent('SubComponent').renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim COMPONENT_CONTENT 'SubComponent'

    output = new (BlazeComponent.getComponent('SubComponent'))().renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim COMPONENT_CONTENT 'SubComponent'

  testGetComponent: ->
    @assertEqual BlazeComponent.getComponent('MainComponent'), MainComponent
    @assertEqual BlazeComponent.getComponent('FooComponent'), FooComponent
    @assertEqual BlazeComponent.getComponent('SubComponent'), SubComponent
    @assertEqual BlazeComponent.getComponent('unknown'), null

  testComponentName: ->
    @assertEqual MainComponent.componentName(), 'MainComponent'
    @assertEqual FooComponent.componentName(), 'FooComponent'
    @assertEqual SubComponent.componentName(), 'SubComponent'
    @assertEqual BlazeComponent.componentName(), null

  testSelfRegister: ->
    @assertTrue BlazeComponent.getComponent 'SelfRegisterComponent'

  testUnregisteredComponent: ->
    output = UnregisteredComponent.renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim COMPONENT_CONTENT 'UnregisteredComponent'

    output = new UnregisteredComponent().renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim COMPONENT_CONTENT 'UnregisteredComponent'

    output = SelfNameUnregisteredComponent.renderComponentToHTML null, null,
      top: '42'

    # We have not extended any helper on purpose, so they should still use "UnregisteredComponent".
    @assertEqual trim(output), trim COMPONENT_CONTENT 'SelfNameUnregisteredComponent', 'UnregisteredComponent'

    output = new SelfNameUnregisteredComponent().renderComponentToHTML null, null,
      top: '42'

    # We have not extended any helper on purpose, so they should still use "UnregisteredComponent".
    @assertEqual trim(output), trim COMPONENT_CONTENT 'SelfNameUnregisteredComponent', 'UnregisteredComponent'

  testErrors: ->
    @assertThrows =>
      BlazeComponent.register()
    ,
      /Component name is required for registration/

    @assertThrows =>
      BlazeComponent.register 'MainComponent', null
    ,
      /Component 'MainComponent' already registered/

    @assertThrows =>
      BlazeComponent.register 'OtherMainComponent', MainComponent
    ,
      /Component 'OtherMainComponent' already registered under the name 'MainComponent'/

    class WithoutTemplateComponent extends BlazeComponent

    @assertThrows =>
      WithoutTemplateComponent.renderComponentToHTML()
    ,
      /Template for the component 'unnamed' not provided/

    @assertThrows =>
      new WithoutTemplateComponent().renderComponentToHTML()
    ,
      /Template for the component 'unnamed' not provided/

    class WithUnknownTemplateComponent extends BlazeComponent
      @componentName 'WithoutTemplateComponent'

      template: ->
        'TemplateWhichDoesNotExist'

    @assertThrows =>
      WithUnknownTemplateComponent.renderComponentToHTML()
    ,
      /Template 'TemplateWhichDoesNotExist' cannot be found/

    @assertThrows =>
      new WithUnknownTemplateComponent().renderComponentToHTML()
    ,
      /Template 'TemplateWhichDoesNotExist' cannot be found/

  testClientEvents: [
    ->
      MainComponent.calls = []
      SubComponent.calls = []

      @renderedComponent = Blaze.render Template.eventsTestTemplate, $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      $('.eventsTestTemplate button').each (i, button) =>
        $(button).click()

      @assertEqual MainComponent.calls, [
        ['MainComponent', 'MainComponent.onClick', {top: '42'}, {top: '42'}, 'MainComponent']
        ['MainComponent', 'MainComponent.onClick', {top: '42'}, {a: '1', b: '2'}, 'MainComponent']
        ['MainComponent', 'MainComponent.onClick', {top: '42'}, {top: '42'}, 'MainComponent']
        ['MainComponent', 'MainComponent.onClick', {top: '42'}, {a: '3', b: '4'}, 'MainComponent']
        ['MainComponent', 'MainComponent.onClick', {top: '42'}, {top: '42'}, 'FooComponent']
        ['MainComponent', 'MainComponent.onClick', {top: '42'}, {a: '5', b: '6'}, 'FooComponent']
        ['MainComponent', 'MainComponent.onClick', {top: '42'}, {top: '42'}, 'SubComponent']
        ['MainComponent', 'MainComponent.onClick', {top: '42'}, {a: '1', b: '2'}, 'SubComponent']
        ['MainComponent', 'MainComponent.onClick', {top: '42'}, {top: '42'}, 'SubComponent']
        ['MainComponent', 'MainComponent.onClick', {top: '42'}, {a: '3', b: '4'}, 'SubComponent']
        ['MainComponent', 'MainComponent.onClick', {top: '42'}, {top: '42'}, 'FooComponent']
        ['MainComponent', 'MainComponent.onClick', {top: '42'}, {a: '5', b: '6'}, 'FooComponent']
      ]

      @assertEqual SubComponent.calls, [
        ['SubComponent', 'SubComponent.onClick', {top: '42'}, {top: '42'}, 'SubComponent']
        ['SubComponent', 'SubComponent.onClick', {top: '42'}, {a: '1', b: '2'}, 'SubComponent']
        ['SubComponent', 'SubComponent.onClick', {top: '42'}, {top: '42'}, 'SubComponent']
        ['SubComponent', 'SubComponent.onClick', {top: '42'}, {a: '3', b: '4'}, 'SubComponent']
        ['SubComponent', 'SubComponent.onClick', {top: '42'}, {top: '42'}, 'FooComponent']
        ['SubComponent', 'SubComponent.onClick', {top: '42'}, {a: '5', b: '6'}, 'FooComponent']
      ]

      Blaze.remove @renderedComponent
  ]

  testClientAnimation: [
    ->
      AnimatedListComponent.calls = []

      @renderedComponent = Blaze.render Template.animationTestTemplate, $('body').get(0)

      Meteor.setTimeout @expect(), 2500 # ms
  ,
    ->
      Blaze.remove @renderedComponent
      calls = AnimatedListComponent.calls
      AnimatedListComponent.calls = []

      expectedCalls = [
        ['insertDOMElement', 'AnimatedListComponent', '<div class="animationTestTemplate"></div>', '<div><ul><li>1</li><li>2</li><li>3</li><li>4</li><li>5</li></ul></div>', '']
        ['removeDOMElement', 'AnimatedListComponent', '<ul><li>1</li><li>2</li><li>3</li><li>4</li><li>5</li></ul>', '<li>1</li>']
        ['moveDOMElement', 'AnimatedListComponent', '<ul><li>2</li><li>3</li><li>4</li><li>5</li></ul>', '<li>5</li>', '']
        ['insertDOMElement', 'AnimatedListComponent', '<ul><li>5</li><li>2</li><li>3</li><li>4</li></ul>', '<li>6</li>', '']
        ['removeDOMElement', 'AnimatedListComponent', '<ul><li>5</li><li>2</li><li>3</li><li>4</li><li>6</li></ul>', '<li>2</li>']
        ['moveDOMElement', 'AnimatedListComponent', '<ul><li>5</li><li>3</li><li>4</li><li>6</li></ul>', '<li>6</li>', '']
        ['insertDOMElement', 'AnimatedListComponent', '<ul><li>6</li><li>5</li><li>3</li><li>4</li></ul>', '<li>7</li>', '']
      ]

      # There could be some more calls made, we ignore them and just take the first 8.
      @assertEqual calls[0...8], expectedCalls

      Meteor.setTimeout @expect(), 2000 # ms
  ,
    ->
      # After we removed the component no more calls should be made.

      @assertEqual AnimatedListComponent.calls, []
  ]

  assertArgumentsConstructorStateChanges: (stateChanges, wrappedInComponent=true, staticRender=false) ->
    firstSteps = (dataContext) =>
      change = stateChanges.shift()
      componentId = change.componentId
      @assertTrue change.view
      @assertTrue change.templateInstance

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertFalse change.isCreated

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertFalse change.isRendered

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertFalse change.isDestroyed

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.data

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertEqual change.currentData, dataContext

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertInstanceOf change.component, ArgumentsComponent

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      if wrappedInComponent
        @assertInstanceOf change.currentComponent, ArgumentsTestComponent
      else
        @assertIsNull change.currentComponent

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.firstNode

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.lastNode

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.subscriptionsReady

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.find

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.findAll

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.$

      componentId

    firstComponentId = firstSteps a: "1", b: "2"
    secondComponentId = firstSteps a:"3a", b: "4a"
    thirdComponentId = firstSteps a: "5", b: "6"
    forthComponentId = firstSteps {}

    if staticRender
      @assertEqual stateChanges, []
      return

    secondSteps = (componentId, dataContext) =>
      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertEqual change.data, dataContext

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertTrue change.subscriptionsReady

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertTrue change.isCreated

    secondSteps firstComponentId, a: "1", b: "2"
    secondSteps secondComponentId, a:"3a", b: "4a"
    secondSteps thirdComponentId, a: "5", b: "6"
    secondSteps forthComponentId, {}

    thirdSteps = (componentId) =>
      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertTrue change.isRendered

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertEqual change.firstNode?.nodeName, "P"

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertEqual change.lastNode?.nodeName, "P"

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertEqual change.find?.nodeName, "P"

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertEqual (c?.nodeName for c in change.findAll), ["P", "P", "P", "P"]

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertEqual (c?.nodeName for c in change.$), ["P", "P", "P", "P"]

    thirdSteps firstComponentId
    thirdSteps secondComponentId
    thirdSteps thirdComponentId
    thirdSteps forthComponentId

    # TODO: This change is probably unnecessary? Could we prevent it?
    change = stateChanges.shift()
    @assertEqual change.componentId, forthComponentId
    if change.data
      # TODO: In Chrome data is set. Why?
      @assertEqual change.data, a: "10", b: "11"
    else
      # TODO: In Firefox data is undefined. Why?
      @assertIsUndefined change.data

    # TODO: Not sure why this change happens?
    change = stateChanges.shift()
    @assertEqual change.componentId, forthComponentId
    @assertIsUndefined change.currentData

    fifthComponentId = firstSteps a: "10", b: "11"

    forthSteps = (componentId) =>
      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertFalse change.isCreated

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertFalse change.isRendered

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.firstNode

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.lastNode

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.find

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.findAll

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.$

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertTrue change.isDestroyed

      # TODO: Not sure why this change happens?
      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.data

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.subscriptionsReady

    forthSteps forthComponentId

    change = stateChanges.shift()
    @assertEqual change.componentId, fifthComponentId
    @assertEqual change.data, a: "10", b: "11"

    change = stateChanges.shift()
    @assertEqual change.componentId, fifthComponentId
    @assertTrue change.subscriptionsReady

    change = stateChanges.shift()
    @assertEqual change.componentId, fifthComponentId
    @assertTrue change.isCreated

    forthSteps firstComponentId
    forthSteps secondComponentId
    forthSteps thirdComponentId

    change = stateChanges.shift()
    @assertEqual change.componentId, fifthComponentId
    @assertFalse change.isCreated

    # TODO: Why is isRendered not set to false and all related other fields which require it (firstNode, lastNode, find, findAll, $)?

    change = stateChanges.shift()
    @assertEqual change.componentId, fifthComponentId
    @assertTrue change.isDestroyed

    # TODO: Not sure why this change happens?
    change = stateChanges.shift()
    @assertEqual change.componentId, fifthComponentId
    @assertIsUndefined change.data

    change = stateChanges.shift()
    @assertEqual change.componentId, fifthComponentId
    @assertIsUndefined change.subscriptionsReady

    @assertEqual stateChanges, []

  assertArgumentsOnCreatedStateChanges: (stateChanges, staticRender=false) ->
    firstSteps = (dataContext) =>
      change = stateChanges.shift()
      componentId = change.componentId
      @assertTrue change.view
      @assertTrue change.templateInstance

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertTrue change.isCreated

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertFalse change.isRendered

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertFalse change.isDestroyed

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertEqual change.data, dataContext

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertEqual change.currentData, dataContext

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertInstanceOf change.component, ArgumentsComponent

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertInstanceOf change.currentComponent, ArgumentsComponent

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.firstNode

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.lastNode

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertTrue change.subscriptionsReady

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.find

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.findAll

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.$

      componentId

    firstComponentId = firstSteps a: "1", b: "2"
    secondComponentId = firstSteps a:"3a", b: "4a"
    thirdComponentId = firstSteps a: "5", b: "6"
    forthComponentId = firstSteps {}

    if staticRender
      @assertEqual stateChanges, []
      return

    thirdSteps = (componentId) =>
      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertTrue change.isRendered

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertEqual change.firstNode?.nodeName, "P"

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertEqual change.lastNode?.nodeName, "P"

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertEqual change.find?.nodeName, "P"

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertEqual (c?.nodeName for c in change.findAll), ["P", "P", "P", "P"]

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertEqual (c?.nodeName for c in change.$), ["P", "P", "P", "P"]

    thirdSteps firstComponentId
    thirdSteps secondComponentId
    thirdSteps thirdComponentId
    thirdSteps forthComponentId

    # TODO: This change is probably unnecessary? Could we prevent it?
    change = stateChanges.shift()
    @assertEqual change.componentId, forthComponentId
    @assertEqual change.data, a: "10", b: "11"

    # TODO: Not sure why this change happens?
    change = stateChanges.shift()
    @assertEqual change.componentId, forthComponentId
    @assertIsUndefined change.currentData

    fifthComponentId = firstSteps a: "10", b: "11"

    forthSteps = (componentId) =>
      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertFalse change.isCreated

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertFalse change.isRendered

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.firstNode

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.lastNode

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.find

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.findAll

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.$

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertTrue change.isDestroyed

      # TODO: Not sure why this change happens?
      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.data

      change = stateChanges.shift()
      @assertEqual change.componentId, componentId
      @assertIsUndefined change.subscriptionsReady

    forthSteps forthComponentId
    forthSteps firstComponentId
    forthSteps secondComponentId
    forthSteps thirdComponentId

    change = stateChanges.shift()
    @assertEqual change.componentId, fifthComponentId
    @assertFalse change.isCreated

    # TODO: Why is isRendered not set to false and all related other fields which require it (firstNode, lastNode, find, findAll, $)?

    change = stateChanges.shift()
    @assertEqual change.componentId, fifthComponentId
    @assertTrue change.isDestroyed

    # TODO: Not sure why this change happens?
    change = stateChanges.shift()
    @assertEqual change.componentId, fifthComponentId
    @assertIsUndefined change.data

    change = stateChanges.shift()
    @assertEqual change.componentId, fifthComponentId
    @assertIsUndefined change.subscriptionsReady

    @assertEqual stateChanges, []

  testArguments: ->
    ArgumentsComponent.calls = []
    ArgumentsComponent.constructorStateChanges = []
    ArgumentsComponent.onCreatedStateChanges = []

    reactiveContext {}
    reactiveArguments {}

    output = Blaze.toHTMLWithData Template.argumentsTestTemplate,
      top: '42'

    @assertEqual trim(output), trim """
      <div class="argumentsTestTemplate">
        <p>Component data context: {"a":"1","b":"2"}</p>
        <p>Current data context: {"a":"1","b":"2"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"3a","b":"4a"}</p>
        <p>Current data context: {"a":"3a","b":"4a"}</p>
        <p>Parent data context: {"a":"3","b":"4"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"5","b":"6"}</p>
        <p>Current data context: {"a":"5","b":"6"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: ["7",{"hash":{"a":"8","b":"9"}}]</p>
        <p>Component data context: {}</p>
        <p>Current data context: {}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: [{},{"hash":{}}]</p>
      </div>
    """

    @assertEqual ArgumentsComponent.calls.length, 4

    @assertEqual ArgumentsComponent.calls, [
      undefined
      undefined
      '7'
      {}
    ]

    @assertArgumentsConstructorStateChanges ArgumentsComponent.constructorStateChanges, true, true
    @assertArgumentsOnCreatedStateChanges ArgumentsComponent.onCreatedStateChanges, true

  testClientArguments: [
    ->
      ArgumentsComponent.calls = []
      ArgumentsComponent.constructorStateChanges = []
      ArgumentsComponent.onCreatedStateChanges = []

      reactiveContext {}
      reactiveArguments {}

      @renderedComponent = Blaze.renderWithData Template.argumentsTestTemplate, {top: '42'}, $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.argumentsTestTemplate').html()), trim """
        <p>Component data context: {"a":"1","b":"2"}</p>
        <p>Current data context: {"a":"1","b":"2"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"3a","b":"4a"}</p>
        <p>Current data context: {"a":"3a","b":"4a"}</p>
        <p>Parent data context: {"a":"3","b":"4"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"5","b":"6"}</p>
        <p>Current data context: {"a":"5","b":"6"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: ["7",{"hash":{"a":"8","b":"9"}}]</p>
        <p>Component data context: {}</p>
        <p>Current data context: {}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: [{},{"hash":{}}]</p>
      """

      reactiveContext {a: '10', b: '11'}

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.argumentsTestTemplate').html()), trim """
        <p>Component data context: {"a":"1","b":"2"}</p>
        <p>Current data context: {"a":"1","b":"2"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"3a","b":"4a"}</p>
        <p>Current data context: {"a":"3a","b":"4a"}</p>
        <p>Parent data context: {"a":"3","b":"4"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"5","b":"6"}</p>
        <p>Current data context: {"a":"5","b":"6"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: ["7",{"hash":{"a":"8","b":"9"}}]</p>
        <p>Component data context: {"a":"10","b":"11"}</p>
        <p>Current data context: {"a":"10","b":"11"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: [{},{"hash":{}}]</p>
      """

      reactiveArguments {a: '12', b: '13'}

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.argumentsTestTemplate').html()), trim """
        <p>Component data context: {"a":"1","b":"2"}</p>
        <p>Current data context: {"a":"1","b":"2"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"3a","b":"4a"}</p>
        <p>Current data context: {"a":"3a","b":"4a"}</p>
        <p>Parent data context: {"a":"3","b":"4"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"5","b":"6"}</p>
        <p>Current data context: {"a":"5","b":"6"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: ["7",{"hash":{"a":"8","b":"9"}}]</p>
        <p>Component data context: {"a":"10","b":"11"}</p>
        <p>Current data context: {"a":"10","b":"11"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: [{"a":"12","b":"13"},{"hash":{}}]</p>
      """

      Blaze.remove @renderedComponent

      # It is important that this is 5, not 6, because we have 3 components with static arguments, and we change
      # arguments twice. Component should not be created once more just because we changed its data context.
      # Only when we change its arguments.
      @assertEqual ArgumentsComponent.calls.length, 5

      @assertEqual ArgumentsComponent.calls, [
        undefined
        undefined
        '7'
        {}
        {a: '12', b: '13'}
      ]

      Tracker.afterFlush @expect()
  ,
    ->
      @assertArgumentsConstructorStateChanges ArgumentsComponent.constructorStateChanges
      @assertArgumentsOnCreatedStateChanges ArgumentsComponent.onCreatedStateChanges
  ]

  testExistingClassHierarchy: ->
    # We want to allow one to reuse existing class hierarchy they might already have and only
    # add the Meteor components "nature" to it. This is simply done by extending the base class
    # and base class prototype with those from a wanted base class and prototype.
    output = BlazeComponent.getComponent('ExistingClassHierarchyComponent').renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim COMPONENT_CONTENT 'ExistingClassHierarchyComponent', 'ExistingClassHierarchyComponent', 'ExistingClassHierarchyBase'

  testMixins: ->
    DependencyMixin.calls = []
    WithMixinsComponent.output = []

    output = BlazeComponent.getComponent('WithMixinsComponent').renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim """
      #{COMPONENT_CONTENT 'WithMixinsComponent', 'SecondMixin', 'FirstMixin'}
      <hr>
      #{COMPONENT_CONTENT 'SubComponent'}
    """

    @assertEqual DependencyMixin.calls, [true]

    @assertInstanceOf WithMixinsComponent.output[1], FirstMixin
    @assertEqual WithMixinsComponent.output[2], WithMixinsComponent.output[1]
    @assertEqual WithMixinsComponent.output[3], null
    @assertInstanceOf WithMixinsComponent.output[4], DependencyMixin
    @assertEqual WithMixinsComponent.output[5], null
    @assertInstanceOf WithMixinsComponent.output[6], SecondMixin
    @assertEqual WithMixinsComponent.output[7], WithMixinsComponent.output[1]
    @assertEqual WithMixinsComponent.output[8], WithMixinsComponent.output[0]
    @assertEqual WithMixinsComponent.output[9], WithMixinsComponent.output[0]
    @assertEqual WithMixinsComponent.output[10], WithMixinsComponent.output[6]

    output = new (BlazeComponent.getComponent('WithMixinsComponent'))().renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim """
      #{COMPONENT_CONTENT 'WithMixinsComponent', 'SecondMixin', 'FirstMixin'}
      <hr>
      #{COMPONENT_CONTENT 'SubComponent'}
    """

  testClientMixinEvents: ->
    FirstMixin.calls = []
    SecondMixin.calls = []
    SubComponent.calls = []

    renderedComponent = Blaze.render Template.mixinEventsTestTemplate, $('body').get(0)

    $('.mixinEventsTestTemplate button').each (i, button) =>
      $(button).click()

    @assertEqual FirstMixin.calls, [
      ['WithMixinsComponent', 'FirstMixin.onClick', {top: '42'}, {top: '42'}, 'WithMixinsComponent']
      ['WithMixinsComponent', 'FirstMixin.onClick', {top: '42'}, {a: '1', b: '2'}, 'WithMixinsComponent']
      ['WithMixinsComponent', 'FirstMixin.onClick', {top: '42'}, {top: '42'}, 'WithMixinsComponent']
      ['WithMixinsComponent', 'FirstMixin.onClick', {top: '42'}, {a: '3', b: '4'}, 'WithMixinsComponent']
      ['WithMixinsComponent', 'FirstMixin.onClick', {top: '42'}, {top: '42'}, 'FooComponent']
      ['WithMixinsComponent', 'FirstMixin.onClick', {top: '42'}, {a: '5', b: '6'}, 'FooComponent']
      ['WithMixinsComponent', 'FirstMixin.onClick', {top: '42'}, {top: '42'}, 'SubComponent']
      ['WithMixinsComponent', 'FirstMixin.onClick', {top: '42'}, {a: '1', b: '2'}, 'SubComponent']
      ['WithMixinsComponent', 'FirstMixin.onClick', {top: '42'}, {top: '42'}, 'SubComponent']
      ['WithMixinsComponent', 'FirstMixin.onClick', {top: '42'}, {a: '3', b: '4'}, 'SubComponent']
      ['WithMixinsComponent', 'FirstMixin.onClick', {top: '42'}, {top: '42'}, 'FooComponent']
      ['WithMixinsComponent', 'FirstMixin.onClick', {top: '42'}, {a: '5', b: '6'}, 'FooComponent']
    ]

    # Event handlers are independent from each other among mixins. SecondMixin has its own onClick
    # handler registered, so it should be called as well.
    @assertEqual SecondMixin.calls, [
      ['WithMixinsComponent', 'SecondMixin.onClick', {top: '42'}, {top: '42'}, 'WithMixinsComponent']
      ['WithMixinsComponent', 'SecondMixin.onClick', {top: '42'}, {a: '1', b: '2'}, 'WithMixinsComponent']
      ['WithMixinsComponent', 'SecondMixin.onClick', {top: '42'}, {top: '42'}, 'WithMixinsComponent']
      ['WithMixinsComponent', 'SecondMixin.onClick', {top: '42'}, {a: '3', b: '4'}, 'WithMixinsComponent']
      ['WithMixinsComponent', 'SecondMixin.onClick', {top: '42'}, {top: '42'}, 'FooComponent']
      ['WithMixinsComponent', 'SecondMixin.onClick', {top: '42'}, {a: '5', b: '6'}, 'FooComponent']
      ['WithMixinsComponent', 'SecondMixin.onClick', {top: '42'}, {top: '42'}, 'SubComponent']
      ['WithMixinsComponent', 'SecondMixin.onClick', {top: '42'}, {a: '1', b: '2'}, 'SubComponent']
      ['WithMixinsComponent', 'SecondMixin.onClick', {top: '42'}, {top: '42'}, 'SubComponent']
      ['WithMixinsComponent', 'SecondMixin.onClick', {top: '42'}, {a: '3', b: '4'}, 'SubComponent']
      ['WithMixinsComponent', 'SecondMixin.onClick', {top: '42'}, {top: '42'}, 'FooComponent']
      ['WithMixinsComponent', 'SecondMixin.onClick', {top: '42'}, {a: '5', b: '6'}, 'FooComponent']
    ]

    @assertEqual SubComponent.calls, [
      ['SubComponent', 'SubComponent.onClick', {top: '42'}, {top: '42'}, 'SubComponent']
      ['SubComponent', 'SubComponent.onClick', {top: '42'}, {a: '1', b: '2'}, 'SubComponent']
      ['SubComponent', 'SubComponent.onClick', {top: '42'}, {top: '42'}, 'SubComponent']
      ['SubComponent', 'SubComponent.onClick', {top: '42'}, {a: '3', b: '4'}, 'SubComponent']
      ['SubComponent', 'SubComponent.onClick', {top: '42'}, {top: '42'}, 'FooComponent']
      ['SubComponent', 'SubComponent.onClick', {top: '42'}, {a: '5', b: '6'}, 'FooComponent']
    ]

    Blaze.remove renderedComponent

  testAfterCreateValue: ->
    # We want to test that also properties added in onCreated hook are available in the template.
    output = BlazeComponent.getComponent('AfterCreateValueComponent').renderComponentToHTML()

    @assertEqual trim(output), trim """
      <p>42</p>
      <p>43</p>
    """

  testClientPostMessageExample: [
    ->
      @renderedComponent = Blaze.render PostMessageButtonComponent.renderComponent(), $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.postMessageButtonComponent').html()), trim """
        <button>Red</button>
      """

      window.postMessage {color: "Blue"}, '*'

      # Wait a bit for a message and also wait for a flush.
      Meteor.setTimeout @expect(), 50 # ms
      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.postMessageButtonComponent').html()), trim """
        <button>Blue</button>
      """

      Blaze.remove @renderedComponent
  ]

  testBlockComponent: ->
    output = Blaze.toHTMLWithData Template.testBlockComponent,
      top: '42'

    @assertEqual trim(output), trim """
      <table>
        <thead>
          <tr>
            <th>Name</th>
            <th>Email</th>
          </tr>
        </thead>
        <tbody>
          <p>{"top":"42"}</p>
          <p>{"customers":[{"name":"Foo","email":"foo@example.com"}]}</p>
          <p class="inside">{"top":"42"}</p>
          <td>Foo</td>
          <td>foo@example.com</td>
        </tbody>
      </table>
       <table>
        <thead>
          <tr>
            <th>Name</th>
            <th>Email</th>
          </tr>
        </thead>
        <tbody>
          <p>{"customers":[{"name":"Foo","email":"foo@example.com"}]}</p>
          <p>{"a":"3a","b":"4a"}</p>
          <p class="inside">{"top":"42"}</p>
          <td>Foo</td>
          <td>foo@example.com</td>
        </tbody>
      </table>
       <table>
        <thead>
          <tr>
            <th>Name</th>
            <th>Email</th>
          </tr>
        </thead>
        <tbody>
          <p>{"top":"42"}</p>
          <p>{"customers":[{"name":"Foo","email":"foo@example.com"}]}</p>
          <p class="inside">{"top":"42"}</p>
          <td>Foo</td>
          <td>foo@example.com</td>
        </tbody>
      </table>
       <table>
        <thead>
          <tr>
            <th>Name</th>
            <th>Email</th>
          </tr>
        </thead>
        <tbody>
          <p>{"top":"42"}</p>
          <p>{"customers":[{"name":"Foo","email":"foo@example.com"}]}</p>
          <p class="inside">{"top":"42"}</p>
          <td>Foo</td>
          <td>foo@example.com</td>
        </tbody>
      </table>
    """

  testClientComponentParent: [
    ->
      reactiveChild1 false
      reactiveChild2 false

      @component = new ParentComponent()

      @childComponents = []
      @handle = Tracker.autorun (computation) =>
        @childComponents.push @component.childComponents()

      @childComponentsChild1 = []
      @handleChild1 = Tracker.autorun (computation) =>
        @childComponentsChild1.push @component.childComponentsWith childName: 'child1'

      @childComponentsChild1DOM = []
      @handleChild1DOM = Tracker.autorun (computation) =>
        @childComponentsChild1DOM.push @component.childComponentsWith (child) ->
          # We can search also based on DOM. We use domChanged to be sure check is called
          # every time DOM changes. But it does not seem to be really necessary in this
          # particular test (it passes without it as well). On the other hand domChanged
          # also does not capture all changes. We are searching for an element by CSS class
          # and domChanged is not changed when a class changes on a DOM element.
          #child.domChanged()
          child.$('.child1')?.length

      @renderedComponent = Blaze.render @component.renderComponent(), $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual @component.childComponents(), []

      reactiveChild1 true

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual @component.childComponents().length, 1

      @child1Component = @component.childComponents()[0]

      @assertEqual @child1Component.parentComponent(), @component

      reactiveChild2 true

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual @component.childComponents().length, 2

      @child2Component = @component.childComponents()[1]

      @assertEqual @child2Component.parentComponent(), @component

      reactiveChild1 false

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual @component.childComponents(), [@child2Component]
      @assertEqual @child1Component.parentComponent(), null

      reactiveChild2 false

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual @component.childComponents(), []
      @assertEqual @child2Component.parentComponent(), null

      Blaze.remove @renderedComponent

      @handle.stop()
      @handleChild1.stop()
      @handleChild1DOM.stop()

      @assertEqual @childComponents, [
        []
        [@child1Component]
        [@child1Component, @child2Component]
        [@child2Component]
        []
      ]

      @assertEqual @childComponentsChild1, [
        []
        [@child1Component]
        []
      ]

      @assertEqual @childComponentsChild1DOM, [
        []
        [@child1Component]
        []
      ]
  ]

  testClientCases: [
    ->
      @dataContext = new ReactiveField {case: 'left'}

      @renderedComponent = Blaze.renderWithData Template.useCaseTemplate, (=> @dataContext()), $('body').get(0)

      Tracker.afterFlush @expect()
    ->
      @assertEqual trim($('.useCaseTemplate').html()), trim """
        <p>Left</p>
      """

      @dataContext {case: 'middle'}

      Tracker.afterFlush @expect()
    ->
      @assertEqual trim($('.useCaseTemplate').html()), trim """
        <p>Middle</p>
      """

      @dataContext {case: 'right'}

      Tracker.afterFlush @expect()
    ->
      @assertEqual trim($('.useCaseTemplate').html()), trim """
        <p>Right</p>
      """

      @dataContext {case: 'unknown'}

      Tracker.afterFlush @expect()
    ->
      @assertEqual trim($('.useCaseTemplate').html()), trim """"""

      Blaze.remove @renderedComponent
  ]

  testClientMixinsExample: [
    ->
      @renderedComponent = Blaze.renderWithData BlazeComponent.getComponent('MyComponent').renderComponent(), {top: '42'}, $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.myComponent').html()), trim """
        <p>alternativeName: 42</p>
        <p>values: abc</p>
        <p>templateHelper: 42</p>
        <p>extendedHelper: 3</p>
        <p>name: foobar</p>
        <p>dataContext: {"top":"42"}</p>
      """

      FirstMixin2.calls = []

      $('.myComponent').click()
      @assertEqual FirstMixin2.calls, [true]

      Blaze.remove @renderedComponent
  ]

  testClientReadmeExample: [
    ->
      @renderedComponent = Blaze.render BlazeComponent.getComponent('ExampleComponent').renderComponent(), $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.exampleComponent').html()), trim """
        <button class="increment">Click me</button>
        <p>Counter: 0</p>
        <p>Message: Click more</p>
      """

      $('.exampleComponent .increment').click()

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.exampleComponent').html()), trim """
        <button class="increment">Click me</button>
        <p>Counter: 1</p>
        <p>Message: Click more</p>
      """

      for i in [0..15]
        $('.exampleComponent .increment').click()

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.exampleComponent').html()), trim """
        <button class="increment">Click me</button>
        <p>Counter: 17</p>
        <p>Message: Too many times</p>
      """

      Blaze.remove @renderedComponent
  ]

  testClientReadmeExampleJS: [
    ->
      @renderedComponent = Blaze.render BlazeComponent.getComponent('ExampleComponentJS').renderComponent(), $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.exampleComponent').html()), trim """
        <button class="increment">Click me</button>
        <p>Counter: 0</p>
        <p>Message: Click more</p>
      """

      $('.exampleComponent .increment').click()

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.exampleComponent').html()), trim """
        <button class="increment">Click me</button>
        <p>Counter: 1</p>
        <p>Message: Click more</p>
      """

      for i in [0..15]
        $('.exampleComponent .increment').click()

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.exampleComponent').html()), trim """
        <button class="increment">Click me</button>
        <p>Counter: 17</p>
        <p>Message: Too many times</p>
      """

      Blaze.remove @renderedComponent
  ]

  testClientMixinsExampleWithJavaScript: [
    ->
      @renderedComponent = Blaze.renderWithData BlazeComponent.getComponent('OurComponentJS').renderComponent(), {top: '42'}, $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.myComponent').html()), trim """
        <p>alternativeName: 42</p>
        <p>values: &gt;&gt;&gt;abc&lt;&lt;&lt;</p>
        <p>templateHelper: 42</p>
        <p>extendedHelper: 3</p>
        <p>name: foobar</p>
        <p>dataContext: {"top":"42"}</p>
      """

      FirstMixin2.calls = []

      $('.myComponent').click()
      @assertEqual FirstMixin2.calls, [true]

      Blaze.remove @renderedComponent
  ]

  testClientReadmeExampleES2015: [
    ->
      @renderedComponent = Blaze.render BlazeComponent.getComponent('ExampleComponentES2015').renderComponent(), $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.exampleComponent').html()), trim """
        <button class="increment">Click me</button>
        <p>Counter: 0</p>
        <p>Message: Click more</p>
      """

      $('.exampleComponent .increment').click()

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.exampleComponent').html()), trim """
        <button class="increment">Click me</button>
        <p>Counter: 1</p>
        <p>Message: Click more</p>
      """

      for i in [0..15]
        $('.exampleComponent .increment').click()

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.exampleComponent').html()), trim """
        <button class="increment">Click me</button>
        <p>Counter: 17</p>
        <p>Message: Too many times</p>
      """

      Blaze.remove @renderedComponent
  ]

  testClientMixinsExampleWithES2015: [
    ->
      @renderedComponent = Blaze.renderWithData BlazeComponent.getComponent('OurComponentES2015').renderComponent(), {top: '42'}, $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.myComponent').html()), trim """
        <p>alternativeName: 42</p>
        <p>values: &gt;&gt;&gt;abc&lt;&lt;&lt;</p>
        <p>templateHelper: 42</p>
        <p>extendedHelper: 3</p>
        <p>name: foobar</p>
        <p>dataContext: {"top":"42"}</p>
      """

      FirstMixin2.calls = []

      $('.myComponent').click()
      @assertEqual FirstMixin2.calls, [true]

      Blaze.remove @renderedComponent
  ]

  testOnDestroyedOrder: ->
    OuterComponent.calls = []

    @outerComponent = new (BlazeComponent.getComponent('OuterComponent'))()

    @states = []

    @autorun =>
      @states.push ['outer', @outerComponent.isCreated(), @outerComponent.isRendered(), @outerComponent.isDestroyed()]

    @autorun =>
      @states.push ['inner', @outerComponent.childComponents()[0]?.isCreated(), @outerComponent.childComponents()[0]?.isRendered(), @outerComponent.childComponents()[0]?.isDestroyed()]

    output = @outerComponent.renderComponentToHTML()

    @assertEqual trim(output), trim """
      <div class="outerComponent">
        <p class="innerComponent">Content.</p>
      </div>
    """

    @assertEqual OuterComponent.calls, [
      'OuterComponent onCreated'
      'InnerComponent onCreated'
      'InnerComponent onDestroyed'
      'OuterComponent onDestroyed'
    ]

    @assertEqual @states, [
      ['outer', false, false, false]
      ['inner', undefined, undefined, undefined]
      ['outer', true, false, false]
      ['inner', true, false, false]
      ['inner', undefined, undefined, undefined]
      ['outer', false, false, true]
    ]

  testClientOnDestroyedOrder: [
    ->
      OuterComponent.calls = []

      @outerComponent = new (BlazeComponent.getComponent('OuterComponent'))()

      @states = []

      @autorun =>
        @states.push ['outer', @outerComponent.isCreated(), @outerComponent.isRendered(), @outerComponent.isDestroyed()]

      @autorun =>
        @states.push ['inner', @outerComponent.childComponents()[0]?.isCreated(), @outerComponent.childComponents()[0]?.isRendered(), @outerComponent.childComponents()[0]?.isDestroyed()]

      @renderedComponent = Blaze.render @outerComponent.renderComponent(), $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      Blaze.remove @renderedComponent

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual OuterComponent.calls, [
        'OuterComponent onCreated'
        'InnerComponent onCreated'
        'InnerComponent onRendered'
        'OuterComponent onRendered'
        'InnerComponent onDestroyed'
        'OuterComponent onDestroyed'
      ]

      @assertEqual @states, [
        ['outer', false, false, false]
        ['inner', undefined, undefined, undefined]
        ['outer', true, false, false]
        ['inner', true, false, false]
        ['inner', true, true, false]
        ['outer', true, true, false]
        ['inner', undefined, undefined, undefined]
        ['outer', false, false, true]
      ]
  ]

  testNamespacedArguments: ->
    MyNamespace.Foo.ArgumentsComponent.calls = []
    MyNamespace.Foo.ArgumentsComponent.constructorStateChanges = []
    MyNamespace.Foo.ArgumentsComponent.onCreatedStateChanges = []

    reactiveContext {}
    reactiveArguments {}

    output = Blaze.toHTMLWithData Template.namespacedArgumentsTestTemplate,
      top: '42'

    @assertEqual trim(output), trim """
      <div class="namespacedArgumentsTestTemplate">
        <p>Component data context: {"a":"1","b":"2"}</p>
        <p>Current data context: {"a":"1","b":"2"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"3a","b":"4a"}</p>
        <p>Current data context: {"a":"3a","b":"4a"}</p>
        <p>Parent data context: {"a":"3","b":"4"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"5","b":"6"}</p>
        <p>Current data context: {"a":"5","b":"6"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: ["7",{"hash":{"a":"8","b":"9"}}]</p>
        <p>Component data context: {}</p>
        <p>Current data context: {}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: [{},{"hash":{}}]</p>
      </div>
    """

    @assertEqual MyNamespace.Foo.ArgumentsComponent.calls.length, 4

    @assertEqual MyNamespace.Foo.ArgumentsComponent.calls, [
      undefined
      undefined
      '7'
      {}
    ]

    @assertArgumentsConstructorStateChanges MyNamespace.Foo.ArgumentsComponent.constructorStateChanges, false, true
    @assertArgumentsOnCreatedStateChanges MyNamespace.Foo.ArgumentsComponent.onCreatedStateChanges, true

    OurNamespace.ArgumentsComponent.calls = []
    OurNamespace.ArgumentsComponent.constructorStateChanges = []
    OurNamespace.ArgumentsComponent.onCreatedStateChanges = []

    reactiveContext {}
    reactiveArguments {}

    output = Blaze.toHTMLWithData Template.ourNamespacedArgumentsTestTemplate,
      top: '42'

    @assertEqual trim(output), trim """
      <div class="ourNamespacedArgumentsTestTemplate">
        <p>Component data context: {"a":"1","b":"2"}</p>
        <p>Current data context: {"a":"1","b":"2"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"3a","b":"4a"}</p>
        <p>Current data context: {"a":"3a","b":"4a"}</p>
        <p>Parent data context: {"a":"3","b":"4"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"5","b":"6"}</p>
        <p>Current data context: {"a":"5","b":"6"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: ["7",{"hash":{"a":"8","b":"9"}}]</p>
        <p>Component data context: {}</p>
        <p>Current data context: {}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: [{},{"hash":{}}]</p>
      </div>
    """

    @assertEqual OurNamespace.ArgumentsComponent.calls.length, 4

    @assertEqual OurNamespace.ArgumentsComponent.calls, [
      undefined
      undefined
      '7'
      {}
    ]

    @assertArgumentsConstructorStateChanges OurNamespace.ArgumentsComponent.constructorStateChanges, false, true
    @assertArgumentsOnCreatedStateChanges OurNamespace.ArgumentsComponent.onCreatedStateChanges, true

    OurNamespace.calls = []
    OurNamespace.constructorStateChanges = []
    OurNamespace.onCreatedStateChanges = []

    reactiveContext {}
    reactiveArguments {}

    output = Blaze.toHTMLWithData Template.ourNamespaceComponentArgumentsTestTemplate,
      top: '42'

    @assertEqual trim(output), trim """
      <div class="ourNamespaceComponentArgumentsTestTemplate">
        <p>Component data context: {"a":"1","b":"2"}</p>
        <p>Current data context: {"a":"1","b":"2"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"3a","b":"4a"}</p>
        <p>Current data context: {"a":"3a","b":"4a"}</p>
        <p>Parent data context: {"a":"3","b":"4"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"5","b":"6"}</p>
        <p>Current data context: {"a":"5","b":"6"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: ["7",{"hash":{"a":"8","b":"9"}}]</p>
        <p>Component data context: {}</p>
        <p>Current data context: {}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: [{},{"hash":{}}]</p>
      </div>
    """

    @assertEqual OurNamespace.calls.length, 4

    @assertEqual OurNamespace.calls, [
      undefined
      undefined
      '7'
      {}
    ]

    @assertArgumentsConstructorStateChanges OurNamespace.constructorStateChanges, false, true
    @assertArgumentsOnCreatedStateChanges OurNamespace.onCreatedStateChanges, true

  testClientNamespacedArguments: [
    ->
      MyNamespace.Foo.ArgumentsComponent.calls = []
      MyNamespace.Foo.ArgumentsComponent.constructorStateChanges = []
      MyNamespace.Foo.ArgumentsComponent.onCreatedStateChanges = []

      reactiveContext {}
      reactiveArguments {}

      @renderedComponent = Blaze.renderWithData Template.namespacedArgumentsTestTemplate, {top: '42'}, $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.namespacedArgumentsTestTemplate').html()), trim """
        <p>Component data context: {"a":"1","b":"2"}</p>
        <p>Current data context: {"a":"1","b":"2"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"3a","b":"4a"}</p>
        <p>Current data context: {"a":"3a","b":"4a"}</p>
        <p>Parent data context: {"a":"3","b":"4"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"5","b":"6"}</p>
        <p>Current data context: {"a":"5","b":"6"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: ["7",{"hash":{"a":"8","b":"9"}}]</p>
        <p>Component data context: {}</p>
        <p>Current data context: {}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: [{},{"hash":{}}]</p>
      """

      reactiveContext {a: '10', b: '11'}

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.namespacedArgumentsTestTemplate').html()), trim """
        <p>Component data context: {"a":"1","b":"2"}</p>
        <p>Current data context: {"a":"1","b":"2"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"3a","b":"4a"}</p>
        <p>Current data context: {"a":"3a","b":"4a"}</p>
        <p>Parent data context: {"a":"3","b":"4"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"5","b":"6"}</p>
        <p>Current data context: {"a":"5","b":"6"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: ["7",{"hash":{"a":"8","b":"9"}}]</p>
        <p>Component data context: {"a":"10","b":"11"}</p>
        <p>Current data context: {"a":"10","b":"11"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: [{},{"hash":{}}]</p>
      """

      reactiveArguments {a: '12', b: '13'}

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.namespacedArgumentsTestTemplate').html()), trim """
        <p>Component data context: {"a":"1","b":"2"}</p>
        <p>Current data context: {"a":"1","b":"2"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"3a","b":"4a"}</p>
        <p>Current data context: {"a":"3a","b":"4a"}</p>
        <p>Parent data context: {"a":"3","b":"4"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"5","b":"6"}</p>
        <p>Current data context: {"a":"5","b":"6"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: ["7",{"hash":{"a":"8","b":"9"}}]</p>
        <p>Component data context: {"a":"10","b":"11"}</p>
        <p>Current data context: {"a":"10","b":"11"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: [{"a":"12","b":"13"},{"hash":{}}]</p>
      """

      Blaze.remove @renderedComponent

      # It is important that this is 5, not 6, because we have 3 components with static arguments, and we change
      # arguments twice. Component should not be created once more just because we changed its data context.
      # Only when we change its arguments.
      @assertEqual MyNamespace.Foo.ArgumentsComponent.calls.length, 5

      @assertEqual MyNamespace.Foo.ArgumentsComponent.calls, [
        undefined
        undefined
        '7'
        {}
        {a: '12', b: '13'}
      ]

      Tracker.afterFlush @expect()
  ,
    ->
      @assertArgumentsConstructorStateChanges MyNamespace.Foo.ArgumentsComponent.constructorStateChanges, false
      @assertArgumentsOnCreatedStateChanges MyNamespace.Foo.ArgumentsComponent.onCreatedStateChanges
  ,
    ->
      OurNamespace.ArgumentsComponent.calls = []
      OurNamespace.ArgumentsComponent.constructorStateChanges = []
      OurNamespace.ArgumentsComponent.onCreatedStateChanges = []

      reactiveContext {}
      reactiveArguments {}

      @renderedComponent = Blaze.renderWithData Template.ourNamespacedArgumentsTestTemplate, {top: '42'}, $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.ourNamespacedArgumentsTestTemplate').html()), trim """
        <p>Component data context: {"a":"1","b":"2"}</p>
        <p>Current data context: {"a":"1","b":"2"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"3a","b":"4a"}</p>
        <p>Current data context: {"a":"3a","b":"4a"}</p>
        <p>Parent data context: {"a":"3","b":"4"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"5","b":"6"}</p>
        <p>Current data context: {"a":"5","b":"6"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: ["7",{"hash":{"a":"8","b":"9"}}]</p>
        <p>Component data context: {}</p>
        <p>Current data context: {}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: [{},{"hash":{}}]</p>
      """

      reactiveContext {a: '10', b: '11'}

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.ourNamespacedArgumentsTestTemplate').html()), trim """
        <p>Component data context: {"a":"1","b":"2"}</p>
        <p>Current data context: {"a":"1","b":"2"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"3a","b":"4a"}</p>
        <p>Current data context: {"a":"3a","b":"4a"}</p>
        <p>Parent data context: {"a":"3","b":"4"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"5","b":"6"}</p>
        <p>Current data context: {"a":"5","b":"6"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: ["7",{"hash":{"a":"8","b":"9"}}]</p>
        <p>Component data context: {"a":"10","b":"11"}</p>
        <p>Current data context: {"a":"10","b":"11"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: [{},{"hash":{}}]</p>
      """

      reactiveArguments {a: '12', b: '13'}

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.ourNamespacedArgumentsTestTemplate').html()), trim """
        <p>Component data context: {"a":"1","b":"2"}</p>
        <p>Current data context: {"a":"1","b":"2"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"3a","b":"4a"}</p>
        <p>Current data context: {"a":"3a","b":"4a"}</p>
        <p>Parent data context: {"a":"3","b":"4"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"5","b":"6"}</p>
        <p>Current data context: {"a":"5","b":"6"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: ["7",{"hash":{"a":"8","b":"9"}}]</p>
        <p>Component data context: {"a":"10","b":"11"}</p>
        <p>Current data context: {"a":"10","b":"11"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: [{"a":"12","b":"13"},{"hash":{}}]</p>
      """

      Blaze.remove @renderedComponent

      # It is important that this is 5, not 6, because we have 3 components with static arguments, and we change
      # arguments twice. Component should not be created once more just because we changed its data context.
      # Only when we change its arguments.
      @assertEqual OurNamespace.ArgumentsComponent.calls.length, 5

      @assertEqual OurNamespace.ArgumentsComponent.calls, [
        undefined
        undefined
        '7'
        {}
        {a: '12', b: '13'}
      ]

      Tracker.afterFlush @expect()
  ,
    ->
      @assertArgumentsConstructorStateChanges OurNamespace.ArgumentsComponent.constructorStateChanges, false
      @assertArgumentsOnCreatedStateChanges OurNamespace.ArgumentsComponent.onCreatedStateChanges
  ,
    ->
      OurNamespace.calls = []
      OurNamespace.constructorStateChanges = []
      OurNamespace.onCreatedStateChanges = []

      reactiveContext {}
      reactiveArguments {}

      @renderedComponent = Blaze.renderWithData Template.ourNamespaceComponentArgumentsTestTemplate, {top: '42'}, $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.ourNamespaceComponentArgumentsTestTemplate').html()), trim """
        <p>Component data context: {"a":"1","b":"2"}</p>
        <p>Current data context: {"a":"1","b":"2"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"3a","b":"4a"}</p>
        <p>Current data context: {"a":"3a","b":"4a"}</p>
        <p>Parent data context: {"a":"3","b":"4"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"5","b":"6"}</p>
        <p>Current data context: {"a":"5","b":"6"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: ["7",{"hash":{"a":"8","b":"9"}}]</p>
        <p>Component data context: {}</p>
        <p>Current data context: {}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: [{},{"hash":{}}]</p>
      """

      reactiveContext {a: '10', b: '11'}

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.ourNamespaceComponentArgumentsTestTemplate').html()), trim """
        <p>Component data context: {"a":"1","b":"2"}</p>
        <p>Current data context: {"a":"1","b":"2"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"3a","b":"4a"}</p>
        <p>Current data context: {"a":"3a","b":"4a"}</p>
        <p>Parent data context: {"a":"3","b":"4"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"5","b":"6"}</p>
        <p>Current data context: {"a":"5","b":"6"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: ["7",{"hash":{"a":"8","b":"9"}}]</p>
        <p>Component data context: {"a":"10","b":"11"}</p>
        <p>Current data context: {"a":"10","b":"11"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: [{},{"hash":{}}]</p>
      """

      reactiveArguments {a: '12', b: '13'}

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.ourNamespaceComponentArgumentsTestTemplate').html()), trim """
        <p>Component data context: {"a":"1","b":"2"}</p>
        <p>Current data context: {"a":"1","b":"2"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"3a","b":"4a"}</p>
        <p>Current data context: {"a":"3a","b":"4a"}</p>
        <p>Parent data context: {"a":"3","b":"4"}</p>
        <p>Arguments: []</p>
        <p>Component data context: {"a":"5","b":"6"}</p>
        <p>Current data context: {"a":"5","b":"6"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: ["7",{"hash":{"a":"8","b":"9"}}]</p>
        <p>Component data context: {"a":"10","b":"11"}</p>
        <p>Current data context: {"a":"10","b":"11"}</p>
        <p>Parent data context: {"top":"42"}</p>
        <p>Arguments: [{"a":"12","b":"13"},{"hash":{}}]</p>
      """

      Blaze.remove @renderedComponent

      # It is important that this is 5, not 6, because we have 3 components with static arguments, and we change
      # arguments twice. Component should not be created once more just because we changed its data context.
      # Only when we change its arguments.
      @assertEqual OurNamespace.calls.length, 5

      @assertEqual OurNamespace.calls, [
        undefined
        undefined
        '7'
        {}
        {a: '12', b: '13'}
      ]

      Tracker.afterFlush @expect()
  ,
    ->
      @assertArgumentsConstructorStateChanges OurNamespace.constructorStateChanges, false
      @assertArgumentsOnCreatedStateChanges OurNamespace.onCreatedStateChanges
  ]

  # Test for https://github.com/peerlibrary/meteor-blaze-components/issues/30.
  testTemplateDynamic: ->
    output = BlazeComponent.getComponent('TemplateDynamicTestComponent').renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim """
      #{COMPONENT_CONTENT 'TemplateDynamicTestComponent', 'MainComponent'}
      <hr>
      #{COMPONENT_CONTENT 'SubComponent'}
    """

    output = new (BlazeComponent.getComponent('TemplateDynamicTestComponent'))().renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim """
      #{COMPONENT_CONTENT 'TemplateDynamicTestComponent', 'MainComponent'}
      <hr>
      #{COMPONENT_CONTENT 'SubComponent'}
    """

    output = BlazeComponent.getComponent('FooComponent').renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim FOO_COMPONENT_CONTENT()

    output = new (BlazeComponent.getComponent('FooComponent'))().renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim FOO_COMPONENT_CONTENT()

    output = BlazeComponent.getComponent('SubComponent').renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim COMPONENT_CONTENT 'SubComponent'

    output = new (BlazeComponent.getComponent('SubComponent'))().renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim COMPONENT_CONTENT 'SubComponent'

  testClientGetComponentForElement: [
    ->
      @outerComponent = new (BlazeComponent.getComponent('OuterComponent'))()

      @renderedComponent = Blaze.render @outerComponent.renderComponent(), $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @innerComponent = @outerComponent.childComponents()[0]

      @assertTrue @innerComponent

      @assertEqual BlazeComponent.getComponentForElement($('.outerComponent').get(0)), @outerComponent
      @assertEqual BlazeComponent.getComponentForElement($('.innerComponent').get(0)), @innerComponent

      Blaze.remove @renderedComponent
  ]

  testBlockHelpersStructure: ->
    component = new (BlazeComponent.getComponent('TestBlockComponent'))()

    @assertTrue component

    output = component.renderComponentToHTML null, null,
      top: '42'

    @assertEqual trim(output), trim(TEST_BLOCK_COMPONENT_CONTENT())

  testClientBlockHelpersStructure: [
    ->
      @renderedComponent = Blaze.render Template.extraTestBlockComponent, $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.extraTestBlockComponent').html()), trim(TEST_BLOCK_COMPONENT_CONTENT())

      TestingComponentDebug.structure = {}
      TestingComponentDebug.dumpComponentTree $('.extraTestBlockComponent table').get(0)

      @assertEqual TestingComponentDebug.structure, TEST_BLOCK_COMPONENT_STRUCTURE()

      @assertEqual BlazeComponent.getComponentForElement($('.insideContent').get(0)).componentName(), 'TestBlockComponent'
      @assertEqual BlazeComponent.getComponentForElement($('.insideContentComponent').get(0)).componentName(), 'RowComponent'
      @assertEqual BlazeComponent.getComponentForElement($('.insideBlockHelper').get(0)).componentName(), 'ExtraTableWrapperBlockComponent'
      @assertEqual BlazeComponent.getComponentForElement($('.insideBlockHelperComponent').get(0)).componentName(), 'FootComponent'
      @assertEqual BlazeComponent.getComponentForElement($('.insideBlockHelperTemplate').get(0)).componentName(), 'ExtraTableWrapperBlockComponent'

      Blaze.remove @renderedComponent
  ]

  testClientExtendingTemplate: [
    ->
      mainComponent3Calls = []

      # To make sure we know what to expect from a template, we first test the template.
      @renderedTemplate = Blaze.renderWithData Template.mainComponent3Test, {top: '42'}, $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.mainComponent3').html()), trim """
        <button>Foo1</button>
        <p>mainComponent3.foobar/{"a":"1","b":"2"}/{"a":"1","b":"2"}/{"a":"1","b":"2"}/{"top":"42"}</p>
        <button>Foo2</button>
        <p>mainComponent3.foobar2/{"a":"3","b":"4"}/{"a":"3","b":"4"}/{"a":"1","b":"2"}/{"a":"1","b":"2"}</p>
        <p>mainComponent3.foobar3/{"a":"1","b":"2"}/{"a":"1","b":"2"}/{"a":"1","b":"2"}/{"top":"42"}</p>
      """

      $('.mainComponent3 button').each (i, button) =>
        $(button).click()

      Blaze.remove @renderedTemplate

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual mainComponent3Calls, [
        [Template.mainComponent3, 'mainComponent3.onCreated', {a: "1", b: "2"}, {a: "1", b: "2"}, {top: "42"}]
        [Template.mainComponent3, 'mainComponent3.onRendered', {a: "1", b: "2"}, {a: "1", b: "2"}, {top: "42"}]
        [Template.mainComponent3, 'mainComponent3.onClick', {a: "1", b: "2"}, {a: "1", b: "2"}, {a: "1", b: "2"}, {top: "42"}]
        [Template.mainComponent3, 'mainComponent3.onClick', {a: "3", b: "4"}, {a: "1", b: "2"}, {a: "1", b: "2"}, {top: "42"}]
        [Template.mainComponent3, 'mainComponent3.onDestroyed', {a: "1", b: "2"}, {a: "1", b: "2"}, {top: "42"}]
      ]
  ,
    ->
      mainComponent3Calls = []

      # And now we make a component which extends it.
      @renderedTemplate = Blaze.renderWithData Template.mainComponent3ComponentTest, {top: '42'}, $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.mainComponent3').html()), trim """
        <button>Foo1</button>
        <p>super:mainComponent3.foobar/{"a":"1","b":"2"}/{"a":"1","b":"2"}/{"a":"1","b":"2"}/{"top":"42"}</p>
        <button>Foo2</button>
        <p>mainComponent3.foobar2/{"a":"3","b":"4"}/{"a":"3","b":"4"}/{"a":"1","b":"2"}/{"a":"1","b":"2"}</p>
        <p>mainComponent3.foobar3/{"a":"1","b":"2"}/{"a":"1","b":"2"}/{"a":"1","b":"2"}/{"top":"42"}</p>
      """

      $('.mainComponent3 button').each (i, button) =>
        $(button).click()

      Blaze.remove @renderedTemplate

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual mainComponent3Calls, [
        [MainComponent3, 'mainComponent3.onCreated', {a: "1", b: "2"}, {a: "1", b: "2"}, {top: "42"}]
        [MainComponent3, 'mainComponent3.onRendered', {a: "1", b: "2"}, {a: "1", b: "2"}, {top: "42"}]
        [MainComponent3, 'mainComponent3.onClick', {a: "1", b: "2"}, {a: "1", b: "2"}, {a: "1", b: "2"}, {top: "42"}]
        [MainComponent3, 'mainComponent3.onClick', {a: "3", b: "4"}, {a: "1", b: "2"}, {a: "1", b: "2"}, {top: "42"}]
        [MainComponent3, 'mainComponent3.onDestroyed', {a: "1", b: "2"}, {a: "1", b: "2"}, {top: "42"}]
      ]
  ]

  # Test for https://github.com/peerlibrary/meteor-blaze-components/issues/30.
  testLexicalArguments: ->
    return unless Blaze._lexicalBindingLookup

    output = Blaze.toHTMLWithData Template.testLexicalArguments,
      test: ['42']

    @assertEqual trim(output), trim """42"""

  # Test for https://github.com/peerlibrary/meteor-blaze-components/issues/109.
  testIndex: ->
    return unless Blaze._lexicalBindingLookup

    output = Blaze.toHTMLWithData Template.testIndex,
      test: ['42']

    @assertEqual trim(output), trim """0"""

  testLexicalArgumentsComponent: ->
    output = BlazeComponent.getComponent('LexicalArgumentsComponent').renderComponentToHTML null, null,
      test: [1, 2, 3]

    @assertEqual trim(output), trim """
      <div>{"test":[1,2,3]}</div>
      <div>1/0</div>
      <div>{"test":[1,2,3]}</div>
      <div>2/1</div>
      <div>{"test":[1,2,3]}</div>
      <div>3/2</div>
    """

  testInlineEventsToHTML: ->
    output = Blaze.toHTML Template.inlineEventsTestTemplate

    @assertEqual trim(output), trim """
      <div class="inlineEventsTestTemplate">
        <form>
          <div>
            <button class="button1" type="button">Button 1</button>
            <button class="button2" type="button">Button 2</button>
            <button class="button3 dynamic" type="button">Button 3</button>
            <button class="button4 dynamic" type="button">Button 4</button>
            <button class="button5" type="button" title="Foobar">Button 5</button>
            <input type="text">
            <textarea></textarea>
          </div>
        </form>
      </div>
    """

  testClientInlineEvents: [
    ->
      reactiveArguments {z: 1}

      InlineEventsComponent.calls = []

      @renderedComponent = Blaze.render Template.inlineEventsTestTemplate, $('body').get(0)

      Tracker.afterFlush @expect()
  ,
    ->
      @assertEqual trim($('.inlineEventsTestTemplate').html()), trim """
        <form>
          <div>
            <button class="button1" type="button">Button 1</button>
            <button class="button2" type="button">Button 2</button>
            <button class="button3 dynamic" type="button">Button 3</button>
            <button class="button4 dynamic" type="button">Button 4</button>
            <button class="button5" type="button" title="Foobar">Button 5</button>
            <input type="text">
            <textarea></textarea>
          </div>
        </form>
      """

      # Event handlers should not be called like template heleprs.
      @assertEqual InlineEventsComponent.calls, []
      InlineEventsComponent.calls = []

      $('.inlineEventsTestTemplate button').each (i, button) =>
        $(button).click()

      $('.inlineEventsTestTemplate textarea').each (i, textarea) =>
        $(textarea).change()

      $('.inlineEventsTestTemplate input').each (i, input) =>
        $(input).click()

      @assertEqual InlineEventsComponent.calls, [
        ['InlineEventsComponent', 'InlineEventsComponent.onButton1Click', {top: '42'}, {a: '1', b: '2'}, 'InlineEventsComponent']
        ['InlineEventsComponent', 'InlineEventsComponent.onClick1Extra', {top: '42'}, {a: '1', b: '2'}, 'InlineEventsComponent']
        ['InlineEventsComponent', 'InlineEventsComponent.onButton2Click', {top: '42'}, {a: '3', b: '4'}, 'InlineEventsComponent']
        ['InlineEventsComponent', 'InlineEventsComponent.onButton3Click', {top: '42'}, {a: '5', b: '6'}, 'InlineEventsComponent', 'foobar', {z: 1}, new Spacebars.kw()]
        ['InlineEventsComponent', 'InlineEventsComponent.onButton4Click', {top: '42'}, {a: '7', b: '8'}, 'InlineEventsComponent', new Spacebars.kw({foo: {z: 1}})]
        ['InlineEventsComponent', 'InlineEventsComponent.extraArgs1', {top: '42'}, {a: '9', b: '10'}, 'InlineEventsComponent']
        ['InlineEventsComponent', 'InlineEventsComponent.extraArgs2', {top: '42'}, {a: '9', b: '10'}, 'InlineEventsComponent']
        ['InlineEventsComponent', 'InlineEventsComponent.onChange', {top: '42'}, {top: '42'}, 'InlineEventsComponent']
        ['InlineEventsComponent', 'InlineEventsComponent.onTextClick', {top: '42'}, {a: '11', b: '12'}, 'InlineEventsComponent']
      ]

      InlineEventsComponent.calls = []

      reactiveArguments {z: 2}

      Tracker.afterFlush @expect()
  ,
    ->
      $('.inlineEventsTestTemplate button').each (i, button) =>
        $(button).click()

      $('.inlineEventsTestTemplate textarea').each (i, textarea) =>
        $(textarea).change()

      $('.inlineEventsTestTemplate input').each (i, input) =>
        $(input).click()

      @assertEqual InlineEventsComponent.calls, [
        ['InlineEventsComponent', 'InlineEventsComponent.onButton1Click', {top: '42'}, {a: '1', b: '2'}, 'InlineEventsComponent']
        ['InlineEventsComponent', 'InlineEventsComponent.onClick1Extra', {top: '42'}, {a: '1', b: '2'}, 'InlineEventsComponent']
        ['InlineEventsComponent', 'InlineEventsComponent.onButton2Click', {top: '42'}, {a: '3', b: '4'}, 'InlineEventsComponent']
        ['InlineEventsComponent', 'InlineEventsComponent.onButton3Click', {top: '42'}, {a: '5', b: '6'}, 'InlineEventsComponent', 'foobar', {z: 2}, new Spacebars.kw()]
        ['InlineEventsComponent', 'InlineEventsComponent.onButton4Click', {top: '42'}, {a: '7', b: '8'}, 'InlineEventsComponent', new Spacebars.kw({foo: {z: 2}})]
        ['InlineEventsComponent', 'InlineEventsComponent.extraArgs1', {top: '42'}, {a: '9', b: '10'}, 'InlineEventsComponent']
        ['InlineEventsComponent', 'InlineEventsComponent.extraArgs2', {top: '42'}, {a: '9', b: '10'}, 'InlineEventsComponent']
        ['InlineEventsComponent', 'InlineEventsComponent.onChange', {top: '42'}, {top: '42'}, 'InlineEventsComponent']
        ['InlineEventsComponent', 'InlineEventsComponent.onTextClick', {top: '42'}, {a: '11', b: '12'}, 'InlineEventsComponent']
      ]

      InlineEventsComponent.calls = []

      $('.inlineEventsTestTemplate button.dynamic').each (i, button) =>
        $(button).trigger('click', 'extraArgument')

      @assertEqual InlineEventsComponent.calls, [
        ['InlineEventsComponent', 'InlineEventsComponent.onButton3Click', {top: '42'}, {a: '5', b: '6'}, 'InlineEventsComponent', 'foobar', {z: 2}, new Spacebars.kw(), 'extraArgument']
        ['InlineEventsComponent', 'InlineEventsComponent.onButton4Click', {top: '42'}, {a: '7', b: '8'}, 'InlineEventsComponent', new Spacebars.kw({foo: {z: 2}}), 'extraArgument']
      ]

      Blaze.remove @renderedComponent
  ]

  testClientInvalidInlineEvents: ->
    @assertThrows =>
      Blaze.render Template.invalidInlineEventsTestTemplate, $('body').get(0)
    ,
      /Invalid event handler/

  testClientBody: ->
    output = Blaze.toHTML Template.body

    @assertTrue $($.parseHTML(output)).is('.bodyTest')

  testServerBody: ->
    output = Blaze.toHTML Template.body

    @assertEqual trim(output), trim """
      <div class="bodyTest">Body test.</div>
    """

  testClientHead: ->
    @assertTrue jQuery('head').find('noscript').length

  testNestedMixins: ->
    LevelTwoComponent.children = []

    output = BlazeComponent.getComponent('LevelOneComponent').renderComponentToHTML null, null

    @assertEqual trim(output), trim """
      <span>41</span>
      <span>42</span>
      <span></span>
    """

    @assertEqual LevelTwoComponent.children, [
      all: 0
    ,
      topValue: 0
    ,
      hasValue: 0
    ,
      hasNoValue: 0
    ,
      all: 1
    ,
      topValue: 1
    ,
      hasValue: 1
    ,
      all: 0
    ,
      topValue: 0
    ,
      hasValue: 0
    ]

ClassyTestCase.addTest new BasicTestCase()
