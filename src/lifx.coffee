# Description:
#   Control my lifx lights
#
# Configuration:
#   HUBOT_LIFX_TOKEN
#
# Commands:
#   hubot lights - show the list of LIFX lights and their groups
#   hubot turn <light|group> <on|off> - Set the LIFX light power status, the value of light and group can be partial names, for example "Bedroom" can just be "bed"
#   hubot scenes - Show the lists of scenes available
#   hubot scene to <scene_name> - Set the scene on your LIFX Lights

# Author:
#   @shahmirj

module.exports = (robot) ->

  headers = {
    'Content-Type': 'application/json',
    'Authorization': "Bearer " + process.env.HUBOT_LIFX_TOKEN
  }

  robot.brain.lifx = {
    'lights': null,
    'scenes': null,
    'length': null
  }

  store_lights = (body) ->
    # Compress the information provided from lifx, into a group
    # light tree
    lights = {}
    for light in body
      if !(lights.hasOwnProperty(light.group.name))
        lights[light.group.name] = {
          'name': light.group.name,
          'id': light.group.id,
          'lights': []
        }
      lights[light.group.name].lights.push(light)

    robot.brain.lifx.lights = lights
    robot.brain.lifx.num = body.length
    robot.brain.context = 'lights'

  robot.respond /(show )?lights?/i, (res) ->
    # Go to the API and return all the lights currently set
    # in the system

    # No token found, bomb out and let the user know
    unless process.env.HUBOT_LIFX_TOKEN?
      res.reply "Sorry no lights are set, *token required!*"
      return

    # Reply to be friendly
    res.reply "_Finding all lights ..._"

    robot.http("https://api.lifx.com/v1/lights/all")
      .headers(headers)
      .get() (err, response, body) ->
        # Compress the information provided into groups
        store_lights(JSON.parse body)

        # Build the text so it can be output to the system
        text = []
        for key, group of robot.brain.lifx.lights
          text.push "\n *" + group.name + "*:"
          for light in group.lights
            if light.connected == false
              text.push "   :red_circle: " + light.label
            else if light.power == "off"
              text.push "   :black_circle: " + light.label
            else
              text.push "   :white_circle: *" + light.label + "*"

        res.reply "...Found " + robot.brain.lifx.num + " *light(s)* you requested:\n" + text.join("\n")

  robot.respond /(?:turn )?(.*) (on|off)$/i, (res) ->
    #console.log(res.match[1], res.match[2])
    send_the_response = (res) ->
      for key,group of robot.brain.lifx.lights
        regex = new RegExp("#{res.match[1]}", "i")
        if key.match regex

          if res.match[2] == "on"
            circle = ":white_circle:"
          else
            circle = ":black_circle:"
          res.reply "Turning *#{key}* light group to *#{res.match[2]}* #{circle}"

          robot.http("https://api.lifx.com/v1/lights/group:#{group.name}/state")
            .headers(headers)
            .put(JSON.stringify { power:res.match[2], duration: 0.2}) (err, response, body) ->
          return

      res.reply "Sorry *no #{res.match[1]} light found*! _try searching for lights by typing `lights`_"

    if robot.brain.lifx.lights == null
      res.reply "No lights found, searching...."
      robot.http("https://api.lifx.com/v1/lights/all")
        .headers(headers)
        .get() (err, response, body) ->
          store_lights(JSON.parse body)
          send_the_response(res)
    else
      send_the_response(res)

  robot.respond /(?:show )?scenes?/i, (res) ->
    # No token found, bomb out and let the user know
    unless process.env.HUBOT_LIFX_TOKEN?
      res.reply "Sorry no scenes are set, *token required!*"
      return

    res.reply "_Searching scenes..._"
    robot.http("https://api.lifx.com/v1/scenes")
      .headers(headers)
      .get() (err, response, body) ->
        robot.brain.lifx.scenes = JSON.parse body

        text = []
        for scene in robot.brain.lifx.scenes
          text.push "  - *" + scene.name + "*"

        res.reply "...Found *" + text.length + "* scene(s):\n" +
            text.join("\n")

  robot.respond /(?:set )?scenes? (.*)$/i, (res) ->
    send_the_response = (res) ->
      for scene in robot.brain.lifx.scenes
        regex = new RegExp("#{res.match[1]}", "i")
        if scene.name.match regex
          res.reply "Switching scene to *#{scene.name}*"

          console.log("https://api.lifx.com/v1/scenes/scene_id:#{scene.uuid}/activate")
          robot.http("https://api.lifx.com/v1/scenes/scene_id:#{scene.uuid}/activate")
            .headers(headers)
            .put() (err, response, body) ->
          return

      res.reply "Sorry *no scene called #{res.match[1]} found*! _try searching for scenes by typing `show scenes`_"

    if robot.brain.lifx.scenes == null
      res.reply "No scene found, searching...."
      robot.http("https://api.lifx.com/v1/scenes")
        .headers(headers)
        .get() (err, response, body) ->
          robot.brain.lifx.scenes = JSON.parse body
          send_the_response(res)
    else
      send_the_response(res)

