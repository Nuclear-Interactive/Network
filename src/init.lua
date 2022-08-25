warn("It is recommended to require the modules inside this container directly instead of getting them through this container module")

return {
    Server = require(script.Server);
    Client = require(script.Client);
}