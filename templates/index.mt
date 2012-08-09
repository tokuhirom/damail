<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>Damail</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.7.0/jquery.min.js"></script>
    <link rel="stylesheet" href="/static/bootstrap/css/bootstrap.min.css">
    <script type="text/javascript" src="/static/bootstrap/js/bootstrap.min.js"></script>
    <script type="text/javascript" src="/static/js/damail.js"></script>
    <script type="text/javascript" src="/static/js/es5-shim.min.js"></script>
    <script type="text/javascript" src="/static/js/micro_template.js"></script>
    <script type="text/javascript" src="/static/js/jquery.hotkeys.js"></script>
    <style>
        .clearfix {zoom:1;}
        .clearfix:after{
            content: ""; 
            display: block; 
            clear: both;}

        header {
            margin-bottom: 30px;
        }
        .body {
            min-height: 400px;
        }
        .folder {
            margin-bottom: 3px;
            cursor: pointer;
        }
        .message {
            overflow: hidden;
            height: 15px;
            margin-bottom: 4px;
            padding: 6px;
            word-break: break-all;
            border-left: white 3px solid;
        }
        .message.seen {
            background-color : #cccccc;
        }
        .message.focus {
            border-left: blue 3px solid;
        }
        .messages {
            border-top: #cccccc 1px solid;
        }
        .messages .checkbox {
            float: left;
            display: block;
            padding: 4px;
        }
        .messages .from {
            width: 200px;
            text-overflow: ellipsis;
            border-right: #cccccc 1px solid;
            display: block;
            float: left;
            pading-top: 9px;
            pading-bottom: 9px;
            padding-left: 6px;
            cursor: pointer;
        }
        .message.selected {
            background-color: #FFC;
        }
        .messages .subject {
            float: left;
            min-width: 200px;
            max-width: 530px;
            text-overflow: ellipsis;
            display: block;
            padding-left: 8px;
            pading-top: 9px;
            pading-bottom: 9px;
            word-break: break-all;
            cursor: pointer;
        }
        .htmlMailIframe {
            border: #cccccc 1px solid;
            padding: 4px;
            border-radisu: 8px;
        }
        .unseenCount.nonEmpty {
            color: red;
        }
        .unseenCount.empty {
            color: #cccccc;
        }

        #loading {
            position: fixed;
            top: 0px;
            width: 200px;
            height: 16px;
            font-size: 10px;
            color: white;
            background-color: green;
            padding: 2px;
        }

        footer {
            text-align: right;
            margin-top: 30px;
        }
    </style>
</head>
<body>
    <div class="container">
        <header><h1><a href="/">Damail</a></h1></header>
        <div class="row body">
            <div class="span2">
                <div id="foldersContainer">
                    now loading folders...
                </div>
            </div>
            <div class="span10">
                <div id="mainPane">
                    now loading..
                </div>
            </div>
        </div>
        <footer>Powered by <a href="http://amon.64p.org/">Amon2::Lite</a></footer>
    </div>

    <div id="loading">Loading...</div>

    <!-- left folders list -->
    <script type="text/template" id="foldersTmpl">
        <% folders.filter(function (e) { return e.hasOwnProperty('UIDVALIDITY'); }).forEach(function (folder) { %>
            <div class="folder" data-name="<%= folder.name %>" data-origname="<%= folder.origname %>"><%= folder.name %><span class="unseenCount <%= folder.UNSEEN ? 'nonEmpty' : 'empty' %>">(<%= folder.UNSEEN %>)</span></div>
        <% }); %>
    </script>

    <!-- message list -->
    <script type="text/template" id="messagesTmpl">
        <div class="messages">
            <% messages.forEach(function (message) { %>
                <div class="message clearfix <%= message.seen ? 'seen' : '' %>"  id="message-<%= message.uid %>" data-message="<%= JSON.stringify(message) %>" data-message_uid="<%= message.uid %>" data-transfer_encoding="<%= message.first_part.transfer_encoding %>" data-message_charset="<%= message.first_part.charset %>" data-subtype="<%= message.first_part.subtype %>">
                    <input type="checkbox" name="mailit" class="checkbox" />
                    <span class="from">
                        <% message.from.forEach(function (from) { %>
                            <% if (from.name) { %>
                                <%= from.name %>
                            <% } else if (from.email) { %>
                                <%= from.email %>
                            <% } else { %>
                                &nbsp;
                            <% } %>
                        <% }); %>
                    </span>
                    <span class="subject"><%= message.subject %></span>
                    <span class="date"><%= JSON.stringify(message)%></span>
                </div>
            <% }); %>
        </div>
    </script>
    <script type="text/template" id="messageTmpl">
        <div id="message">
            <h2><%= message.subject %></h2>
            <dl class="headers">
                <dt>From</dt>
                <dd>
                    <% message.from.forEach(function (from) { %>
                        <% if (from.name) { %>
                            "<%= from.name %>"
                        <% } %>
                        &lt; <%= from.email %>&gt;
                    <% }); %>
                </dd>
                <dt>To</dt>
                <dd>
                    <% message.to.forEach(function (to) { %>
                        <% if (to.name) { %>
                            "<%= to.name %>"
                        <% } %>
                        &lt; <%= to.email %>&gt;
                    <% }); %>
                </dd>
            </dl>
            <% if (message.first_part.subtype == 'html') { %>
                <iframe src="data:text/html;charset=utf-8,<%= encodeURIComponent('<base href="http://example.com/" target="_blank">' + body) %>" width="100%" height="700" class="htmlMailIframe" frameborder="0"></iframe>
            <% } else { %>
                <pre><%= body %></pre>
            <% } %>
        </div>
    </script>
</body>
</html>
