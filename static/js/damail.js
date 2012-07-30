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

    function TODO(msg) {
        if (!msg) { msg = "Not implemented yet"; }
        alert(msg);
    }

    var csrf_token = $(document.body).data('csrf_token');

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
                type: 'post',
                url: '/message/show.json',
                data: {
                    csrf_token: csrf_token,
                    transfer_encoding: transfer_encoding,
                    message_charset: message_charset,
                    message_uid: message_uid
                }
            });
        },
        // @args message_uids: An array of message_uids.
        archiveMessage: function (message_uids) {
            return $.ajax({
                type: 'post',
                url: '/message/archive.json',
                data: {
                    csrf_token: csrf_token,
                    message_uids: message_uids.join(',')
                }
            });
        }
    };

    // controller
    var app = {
        box_limit: 50, // display messages in one page from folder.
        page: 1,
        cursorMessage: null,
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
                app.cursorMessage = null;
                app.cursorDown();
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
            $('.message .from, .message .subject').live('click', function () {
                var messageElem = $(this).parent();
                var message_uid = messageElem.data('message_uid');
                var transfer_encoding = messageElem.data('transfer_encoding');
                var message_charset = messageElem.data('message_charset');
                app.showLoading();
            });

            // key bindings
            $(document).bind('keyup.u', function () {
                app.upFolder();
                return false;
            });
            $(document).bind('keydown.j', function () {
                app.cursorDown();
                return false;
            });
            $(document).bind('keydown.k', function () {
                app.cursorUp();
                return false;
            });
            $(document).bind('keyup.x', function () {
                app.UISelectMessage();
                return false;
            });
            $(document).bind('keyup.o', function () {
                app.UIOpenMessage();
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
        UIOpenMessage: function () {
            var elem = $('#' + this.cursorMessage);
            if (elem.size()) {
                var message = elem.data('message');
                app.showMessage(message);
            }
        },
        showMessage: function (message) {
            IMAPClient.showMessage(message.uid, message.first_part.transfer_encoding, message.first_part.charset).done(function (dat) {
                dat.message = app.messageDataCache[message.uid];
                var html = window.tmpl('messageTmpl', dat);
                $('#mainPane').html(html);
                app.hideLoading();
                console.log('move to top');
                $('html, body').animate({scrollTop: 0}, 'fast');
            });
        },
        upFolder: function () { // move up to last folder
            console.log('upfolder');
            if (app.lastFolder) {
                app.showFolder(app.lastFolder);
            }
        },
        cursorUp: function () { // go to previous mail
            console.log('cursorUp');
            if (this.cursorMessage) {
                var prevElem = $('#' + this.cursorMessage);
                var elem = prevElem.prev();
                if (elem.size()) {
                    elem.addClass('focus');
                    app.scrollToElem(elem);
                    this.cursorMessage = elem.attr('id');
                    prevElem.removeClass('focus');
                } else {
                    if (app.page == 1) {
                        // no operation
                    } else {
                        TODO("Cannot go to next page, yet");
                    }
                }
            } else {
                // not selected any message
                var elem = $('.message:first').addClass('focus');
                this.cursorMessage = $(elem).attr('id');
            }
        },
        cursorDown: function () { // goto next mail
            console.log('cursorDown: ' + this.cursorMessage);
            if (this.cursorMessage) {
                var prevElem = $('#' + this.cursorMessage);
                prevElem.removeClass('focus');
                var elem = prevElem.next();
                if (elem.size()) {
                    elem.addClass('focus');
                    app.scrollToElem(elem);
                    this.cursorMessage = elem.attr('id');
                } else {
                    TODO("Cannot go to next page, yet");
                }
            } else {
                // not selected any message
                var elem = $('.message:first').addClass('focus');
                this.cursorMessage = $(elem).attr('id');
            }
        },
        scrollToElem: function (elem) {
            var speed = 0;
            var easing = undefined;
            var top = $(elem).offset().top;
            $("html:not(:animated),body:not(:animated)")
                .stop()
                .animate({ scrollTop: top-50 }, speed, easing, function() {
            });
        },
        UISelectMessage: function () {
            console.log('select');
            if (this.cursorMessage) {
                var elem = $('#'+this.cursorMessage +' input');
                if (elem.attr('checked')) {
                    elem.removeAttr('checked');
                } else {
                    elem.attr('checked', 'checked');
                }
            }
        },
    };

    // initialize
    app.setupHooks();
    app.loadFolders();
});
