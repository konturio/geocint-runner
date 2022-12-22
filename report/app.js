const fs = require('fs');
const Papa = require('papaparse');
const express = require("express");
const cors = require("cors");
const morgan = require("morgan");
path = require('path')

const app = express();

app.use(cors());
app.use(
  morgan(":method :url :status :res[content-length] - :response-time ms")
);

process.on('uncaughtException', err => {
  console.log(err);
})

app.get('/', async function (req, res) {
  res.json(await parseCsv(csvFilePath));
});

const csvFilePath = path.join(__dirname, 'make_profile.db');
const daysBack = 15;
const logFileName = "failed.touch"
const recTime = 0;
const recLog = 1;
const recEvent = 2;
const recEventName = 3;
const finishTxt = "finish";
const startTxt = "start";
const failedTxt = "failed";
const completedTxt = "completed";
const startedTxt = "started";

let nEvents, nFail, nFrozen, nProgress = 0;
let oldestCompleteTime;
let presentStatus = "Idle"

const parseCsv = async (filePath) => {
  const csvFile = fs.readFileSync(filePath)
  const csvData = csvFile.toString()
  let myJson = [];
  return new Promise(resolve => {
    i = 0;
    Papa.parse(csvData, {
      delimiter: " ",
      complete: results => {
        //lots of dates on logs. filter it
        const daysLimited = new Date(Date.now() - daysBack * 24 * 60 * 60 * 1000)

        //all make_profile.db data
        let records = results.data;

        records.forEach(function (rec, index) {
          let eTime = new Date(rec[recTime] * 1000);

          //get only event names in defined days
          if (eTime > daysLimited) {
            let newItem = {
              eventN: rec[recEventName],
              eventType: null,
              eventTime: null,
              eventDuration: null
            }

            //match all previous start & finish jobs with same event name 
            if (myJson.findIndex(existing => existing.eventN == rec[recEventName]) === -1) {
              myJson.push(newItem)
            }

            myJson.forEach(function (jsonRec) {
              if (jsonRec.eventN == rec[recEventName]) {
                jsonRec.eventTime = eTime;
                jsonRec.lastEventTime = eTime;
                jsonRec.log = rec[recLog];
                if (jsonRec.eventDetails === undefined) {
                  jsonRec.eventDetails = [];
                }
                if (rec[recEvent] === startTxt) {
                  jsonRec.eventType = startedTxt;
                  jsonRec.eventDuration = null;

                  // find last completed time
                  for (var i = jsonRec.eventDetails.length - 1; i >= 0; i--) {
                    if (jsonRec.eventDetails[i].eventType === finishTxt) {
                      jsonRec.lastEventTime = jsonRec.eventDetails[jsonRec.eventDetails.length - 1].date;
                    }
                    break;
                  }

                  //chack if job failed
                  let failedFile = "./logs/" + rec[recLog] + "/" + rec[recEventName] + "/" + logFileName
                  if (fs.existsSync(failedFile)) {
                    jsonRec.eventType = failedTxt;
                    jsonRec.lastEventTime = null;
                  }

                } else if (rec[recEvent] === finishTxt) {
                  jsonRec.eventType = completedTxt
                  if (jsonRec.eventDetails.length > 0) {
                    let duration = eTime - jsonRec.eventDetails[jsonRec.eventDetails.length - 1].date;
                    jsonRec.eventDuration = duration;
                  }
                }

                jsonRec.eventDetails.push(
                  {
                    date: eTime,
                    eventType: rec[recEvent]
                  }
                )
              }
            });
          }
        });

        myJson.sort((a, b) => a.eventTime - b.eventTime).reverse();

        nEvents = myJson.length;

        nFail = myJson.filter(function (el) {
          return el.eventType == failedTxt;
        }).length;

        nProgress = myJson.filter(function (el) {
          return el.eventType == startedTxt;
        }).length;

        if (nProgress > 0) {
          presentStatus = "not finished"
        }

        // find oldest completed time
        for (var i = myJson.length - 1; i >= 0; i--) {
          if (myJson[i].eventType === completedTxt) {
            oldestCompleteTime = myJson[i].eventTime
          }
          break;
        }

        resolve({
          status: myJson,
          pipeline: {
            nProgress: nProgress,
            nEvents: nEvents,
            nFail: nFail,
            nFrozen: nFrozen,
            oldestCompleteTime: oldestCompleteTime,
            presentStatus: presentStatus
          }
        });
      }
    });
  });
};

const start = async () => {
  try {
    const appPort = config.app.port;
    app.listen(appPort);
    console.log('>report server is listening on port ' + appPort);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
};

start();
