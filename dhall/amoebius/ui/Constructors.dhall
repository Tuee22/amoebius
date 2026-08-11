let T = ./Types.dhall

let node =
      \(nodeId : Text) ->
      \(nodeKind : T.NodeKind) ->
      \(valueType : T.ValueType) ->
      \(maxItems : Natural) ->
        { nodeId
        , nodeKind
        , valueType
        , edges = [] : List Text
        , events = [] : List Text
        , branches = [] : List Text
        , maxItems = Some maxItems
        , public = True
        , portType = None T.ValueType
        }

let externalLink = \(name : Text) -> { name }

in  { node, externalLink }
