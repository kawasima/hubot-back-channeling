# hubot-back-channeling

## Get started

1. Install `hubot` and `coffeescript`
    ```
    npm install -g hubot coffee-script
    ```
2. Create your bot.
    ```shell
    npm install -g yo generator-hubot
    mkdir -p myhubot
    yo hubot
    ```
3. Set environment variables.
   ```
   export HUBOT_BACK_CHANNELING_CODE=xxxxxxxxxxx
   export HUBOT_BACK_CHANNELING_THREAD_ID=nnnnnnnnn
   ```
   `CODE` is an authenticated code. It's published when you created a bot account.
4. Start your bot.
   ```
   bin/hubot -a back-channeling -n [back-channeling bot name]
   ```

## License

Copyright © 2015 kawasima

Distributed under the Eclipse Plublic License Version 1.0.
