# Changelog

## [1.0.0]
- Initial Release

## [1.0.1]
- Fail

## [1.0.2]
- Fixed Package

## [1.0.3]
- Attempting to create a Network on the Client that does not exist on the server will now error.

## [1.2.0]
- Revamp
- Structural fixes
  
## [1.2.1]
- Container module changed from `.Server` to `:GetServer()` likewise, `.Client` to `:GetClient()` for getting the module for the server and client.

## [1.2.2]
- Promise alternatives for yielding methods implemented

## [1.2.3]
- Fixed invocation queue behavior bugs with `:Once(...)`
- Type fixes

## [1.2.4]
- If the first argument in `Network.new()` is left nil it defaults to "Default"
- Removed StateAdded in network reserved namespaces