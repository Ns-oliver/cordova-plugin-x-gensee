var exec = require('cordova/exec');

var Gensee = {
    openGensee: function (succcess,failed, args, service) {
        exec(succcess, failed, "GenseeVideo", service, args);
    },
};

module.exports = Gensee;
