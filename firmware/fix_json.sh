#!/bin/bash
sed -i 's/^[ \t]*deserializeJson(doc, server.arg("plain"));/            DeserializationError err = deserializeJson(doc, server.arg("plain"));\n            if (err) {\n                server.send(400, "application\/json", "{\\"error\\":\\"Invalid JSON\\"}");\n                return;\n            }/g' include/web_server_handler.h
