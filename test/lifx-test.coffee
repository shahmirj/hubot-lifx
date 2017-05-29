Helper = require('hubot-test-helper')
expect = require('chai').expect
nock = require('nock')

helper = new Helper('../src/lifx.coffee')

describe 'lifx lights', ->
  room = null

  beforeEach ->
    process.env['HUBOT_LIFX_TOKEN'] = "TOKEN"
    room = helper.createRoom()
    do nock.disableNetConnect
    nock(
      'https://api.lifx.com',
      reqheaders: {
        'Content-Type': 'application/json'
        'Authorization': 'Bearer TOKEN'
      })
      .get('/v1/lights/all')
      .reply(
        200,
        [
          {
            label: 'Hallway Light',
            power: "on",
            connected: true,
            group: {
              id: "0",
              name: "Hallway"
            }
          },
          {
            label: 'Lounge Light',
            power: "on",
            connected: true,
            group: {
              id: "1",
              name: "Lounge"
            }
          },
          {
            label: 'Lounge Lamp',
            power: "off",
            connected: true,
            group: {
              id: "1",
              name: "Lounge"
            }
          },
          {
            label: 'Office Light',
            power: "off",
            connected: false,
            group: {
              id: "2",
              name: "Office"
            }
          }
        ]
      )
      .put('/v1/lights/group_id:1/state', { "power": "on" })
      .reply(201, {})
      .get('/v1/scenes')
      .reply(
        200,
        [
          {
            "uuid": "1",
            "name": "Movie",
          },
          {
            "uuid": "2",
            "name": "Away",
          }
        ]
      )

  afterEach ->
    room.destroy()
    nock.cleanAll()

  context 'user asks hubot for a lights', ->

    beforeEach (done) ->
      room.user.say 'alice', 'hubot lights'
      setTimeout done, 100

    it 'should respond with the lights found', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot lights' ]
        [ 'hubot', '@alice _Finding all lights ..._' ]
        [
          'hubot',
          '@alice '+
            '...Found 4 *light(s)* you requested:\n\n' +
            ' *Hallway*:\n' +
            '   :white_circle: *Hallway Light*\n\n' +
            ' *Lounge*:\n' +
            '   :white_circle: *Lounge Light*\n' +
            '   :black_circle: Lounge Lamp\n\n' +
            ' *Office*:\n' +
            '   :red_circle: Office Light'
        ]
      ]

    it 'context should change to lights', ->
      expect(room.robot.brain.context).to.eq('lights')
      expect(room.robot.brain.lifx.lights).to.deep.equal(
        {
          'Hallway': {
            'name': 'Hallway',
            'id': "0",
            'lights': [
              {
                'label': 'Hallway Light',
                'power': 'on',
                'connected': true,
                'group': {
                  'id': "0",
                  'name': "Hallway"
                }
              }
            ]
          },
          'Lounge': {
            'name': 'Lounge',
            'id': "1",
            'lights': [
              {
                'label': 'Lounge Light',
                'power': 'on',
                'connected': true,
                'group': {
                  'id': "1",
                  'name': "Lounge"
                }
              },
              {
                'label': 'Lounge Lamp',
                'power': 'off',
                'connected': true,
                'group': {
                  'id': "1",
                  'name': "Lounge"
                }
              }
            ]
          },
          'Office': {
            'name': 'Office',
            'id': "2",
            'lights': [
              {
                'label': 'Office Light',
                'power': "off",
                'connected': false,
                'group': {
                  'id': "2",
                  'name': "Office"
                }
              }
            ]
          }
        }
      )
      expect(room.robot.brain.lifx.num).to.eq(4)

  context 'user asks hubot to change light state', ->
    it 'should set the light state to on', ->
      room.user.say('alice', 'hubot turn hallway on').then =>
        expect(room.messages).to.eql [
          [ 'alice', 'hubot turn hallway on' ]
          [ "hubot", "@alice No lights found, searching...." ]
          [ 'hubot', '@alice Turning *Hallway* light group to *on* :white_circle:' ]
        ]

    it 'should set the light state to off', ->
      room.user.say('alice', 'hubot turn hallway off').then =>
        expect(room.messages).to.eql [
          [ 'alice', 'hubot turn hallway off' ]
          [ "hubot", "@alice No lights found, searching...." ]
          [ 'hubot', '@alice Turning *Hallway* light group to *off* :black_circle:' ]
        ]

    it 'should complain as no light is found', ->
      room.user.say('alice', 'hubot turn unknown on').then =>
        expect(room.messages).to.eql [
          [ 'alice', 'hubot turn unknown on' ]
          [ "hubot", "@alice No lights found, searching...." ]
          [ 'hubot', '@alice Sorry *no unknown light found*! _try searching for lights by typing `lights`_' ]
        ]

  context 'user asks for scenes', ->
    it 'should display the list of scenes', ->
      room.user.say('alice', 'hubot show scenes').then =>
        expect(room.messages).to.eql [
          [ 'alice', 'hubot show scenes' ]
          [ 'hubot', '@alice _Searching scenes..._' ]
          [
            'hubot',
            '@alice ...Found *2* scene(s):\n' +
              '  - *Movie*\n' +
              '  - *Away*'
          ]
        ]

  context 'user asks to set scene', ->
    it 'should complain as no light is found', ->
      room.user.say('alice', 'hubot set scene unknown').then =>
        expect(room.messages).to.eql [
          [ 'alice', 'hubot set scene unknown' ]
          [ "hubot", "@alice No scene found, searching...." ]
          [ 'hubot', '@alice Sorry *no scene called unknown found*! _try searching for scenes by typing `show scenes`_' ]
        ]

    it 'should set the scene', ->
      room.user.say('alice', 'hubot set scene away').then =>
        expect(room.messages).to.eql [
          [ 'alice', 'hubot set scene away' ]
          [ "hubot", "@alice No scene found, searching...." ]
          [ 'hubot', '@alice Switching scene to *Away*' ]
        ]
