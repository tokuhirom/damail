$(function () {
    "use strict";

    if (!window.console) {
        window.console = {
            debug: function () { },
            log: function () { }
        };
    }

    $.ajaxSetup({
        error: function (err) {
            console.log(err);
            alert("An error occurred in ajax.");
        }
    });

    // model
    var IMAPClient = {
        getFolders: function () {
            return $.ajax({
                type: 'get',
                url: '/folders.json'
            });
        },
        listMessages: function (folder_name, limit, page) {
            return $.ajax({
                type: 'get',
                url: '/folder/messages.json',
                data: {
                    folder_name: folder_name,
                    limit: limit,
                    page: page
                }
            });
        },
        showMessage: function (message_uid, transfer_encoding, message_charset) {
            return $.ajax({
                type: 'get',
                url: '/message/show.json',
                data: {
                    transfer_encoding: transfer_encoding,
                    message_charset: message_charset,
                    message_uid: message_uid
                }
            });
        },
    };

    // controller
    var app = {
        box_limit: 50, // display messages in one page from folder.
        page: 1,
        lastFolder: null,
        messageDataCache: { },
        loadFolders: function () {
            IMAPClient.getFolders().success(function (dat) {
                console.log(dat);
                var html = window.tmpl('foldersTmpl', dat);
                $('#foldersContainer').html(html);

                if (dat.folders.length > 0) {
                    app.showFolder(dat.folders[0]);
                }
            });
        },
        showFolder: function (folder) {
            app.showLoading();
            console.log(folder);
            IMAPClient.listMessages(folder.name, this.box_limit, this.page).done(function (dat) {
                app.lastFolder = folder;
                console.log(dat);
                var html = window.tmpl('messagesTmpl', dat);
                $('#mainPane').html(html);

                app.hideLoading();

                dat.messages.forEach(function (message) {
                    app.messageDataCache[message.uid] = message;
                });
            });
        },
        setupHooks: function () {
            $('.folder').live('click', function (e) {
                e.stopPropagation();
                e.preventDefault();
                // origname means imap-utf-7 encoded folder name.
                var origname = $(this).data('origname');
                var name = $(this).data('name');
                app.showFolder({
                    origname: origname,
                    name: name
                });
            });
            $('.message').live('click', function () {
                var message_uid = $(this).data('message_uid');
                var transfer_encoding = $(this).data('transfer_encoding');
                var message_charset = $(this).data('message_charset');
                app.showLoading();
                IMAPClient.showMessage(message_uid, transfer_encoding, message_charset).done(function (dat) {
                    dat.message = app.messageDataCache[message_uid];
                    var html = window.tmpl('messageTmpl', dat);
                    $('#mainPane').html(html);
                    app.hideLoading();
                });
            });
            $(document).bind('keyup.u', function () {
                app.upFolder();
                return false;
            });

            $('#loading').css({
                left: ''+($(window).width() - $('#loading').width()) + 'px',
                top: '2px'
            });
            app.hideLoading();
        },
        hideLoading: function () {
            $('#loading').hide();
        },
        showLoading: function () {
            $('#loading').show();
        },
        upFolder: function () { // move up to last folder
            console.log('upfolder');
            if (app.lastFolder) {
                app.showFolder(app.lastFolder);
            }
        }
    };

    // initialize
    app.setupHooks();
    app.loadFolders();
});
