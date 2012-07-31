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
        currentMessage: null,
        lastFolder: null,
        messageDataCache: { },
        prevMessage: {},
        nextMessage: {},
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
                app.nextMessage = {};
                app.prevMessage = {};

                dat.messages.forEach(function (message, i) {
                    app.messageDataCache[message.uid] = message;
                    if (i<dat.messages.length-1) {
                        app.nextMessage[message.uid] = dat.messages[i+1];
                    }
                    if (i>=1) {
                        app.prevMessage[message.uid] = dat.messages[i-1];
                    }
                });
                app.cursorMessage = null;
                app.UICursorDown();

                app.currentMessage = null;
            });
        },
        getNextMessage: function (message_uid) {
        console.log(message_uid);
            return app.nextMessage[message_uid];
        },
        getPrevMessage: function (message_uid) {
            return app.prevMessage[message_uid];
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
                app.UICursorDown();
                return false;
            });
            $(document).bind('keydown.k', function () {
                app.UICursorUp();
                return false;
            });
            $(document).bind('keyup.r', function () {
                app.UIReload();
                return false;
            });
            $(document).bind('keydown.x', function () {
                app.UISelectMessage();
                return false;
            });
            $(document).bind('keyup.o', function () {
                app.UIOpenMessage();
                return false;
            });
            $(document).bind('keyup.e', function () {
                app.UIArchive();
                return false;
            });

            $('#loading').css({
                left: ''+($(window).width() - $('#loading').width()) + 'px',
                top: '2px'
            });
            app.hideLoading();
        },
        UIArchive: function () {
            if (app.isMessageView()) {
                console.log('archiving');
                app.showLoading();
                IMAPClient.archiveMessage([app.currentMessage.uid]).done(function () {
                    app.showFolder(app.lastFolder);
                });
            } else if (app.isFolderView()) {
                console.log('archiving for folder view');
                var uids = app.getSelectedMessageUIDs();
                console.log(uids);
                if (uids.length > 0) {
                    app.showLoading();
                    IMAPClient.archiveMessage(uids).done(function () {
                        app.showFolder(app.lastFolder);
                    });
                }
            } else {
                // nop.
            }
        },
        getSelectedMessages: function () {
            var ret = [];
            $('.messages input:checked').parents('.message').each(function (i, e) {
                var msg = $(e).data('message');
                ret.push(msg);
            });
            return ret;
        },
        getSelectedMessageUIDs: function () {
            var ret = [];
            app.getSelectedMessages().forEach(function (e, i) {
                console.log(e);
                ret.push(e.uid);
            });
            return ret;
        },
        isMessageView: function () {
            // damail is displaying a one message?
            return !!$('#message').size();
        },
        isFolderView: function () {
            // damail is displaying message list in a folder?
            return !!$('.messages').size();
        },
        UIReload: function() {
            if (app.isFolderView() && app.lastFolder) {
                app.showFolder(app.lastFolder);
            }
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
                app.currentMessage = dat.message;
            });
        },
        upFolder: function () { // move up to last folder
            console.log('upfolder');
            if (app.lastFolder) {
                app.showFolder(app.lastFolder);
            }
        },
        UICursorUp: function () { // go to previous mail
            console.log('cursorUp');
            if (app.isFolderView()) {
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
            } else if (app.isMessageView()) {
                var prevMessage = app.getPrevMessage(this.currentMessage.uid);
                if (prevMessage) {
                    app.showMessage(prevMessage);
                }
            }
        },
        UICursorDown: function () { // goto next mail
            console.log('cursorDown: ' + this.cursorMessage);
            if (app.isFolderView()) {
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
            } else if (app.isMessageView()) {
                var nextMessage = app.getNextMessage(this.currentMessage.uid);
                if (nextMessage) {
                    app.showMessage(nextMessage);
                }
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
                    elem.parents('.message').removeClass('selected');
                } else {
                    elem.attr('checked', 'checked');
                    elem.parents('.message').addClass('selected');
                }
            }
        },
        makeClickable: function makeClickable(src) {
            function escapeHTML(str) {
                return str.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
            }

            return src.replace(/(https?:\/\/[^:/<>&]+(:\d+)?(\/[^#\s<>&()"']*(#([<>&"'()]+))?)?)|(.)/gi, function (r, link, part) {
                if (link) {
                    link = escapeHTML(link);
                    return '<a target="_blank" href="' + link + '">' + link + '</a>';
                } else {
                    return escapeHTML(r);
                }
            });
        }
    };
    window.app = app;

    // initialize
    app.setupHooks();
    app.loadFolders();
});
