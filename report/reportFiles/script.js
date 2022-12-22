function filterTarget() {
    var input, filter, table, tr, td, i, txtValue;
    input = document.getElementById("myInput");

    filter = input.value.toUpperCase().split(" ").join("_");
    table = document.getElementById("statusTable");
    tr = table.getElementsByTagName("tr");

    if (filter.startsWith('"') && filter.endsWith('"')) {
        filter = filter.substring(1, filter.length - 1)
        for (i = 0; i < tr.length; i++) {
            td = tr[i].getElementsByTagName("td")[0];
            if (td) {
                txtValue = td.textContent || td.innerText;
                if (txtValue.toUpperCase() === filter) {
                    tr[i].style.display = "";
                } else {
                    tr[i].style.display = "none";
                }
            }
        }
    } else {
        for (i = 0; i < tr.length; i++) {
            td = tr[i].getElementsByTagName("td")[0];
            if (td) {
                txtValue = td.textContent || td.innerText;
                if (txtValue.toUpperCase().indexOf(filter) > -1) {
                    tr[i].style.display = "";
                } else {
                    tr[i].style.display = "none";
                }
            }
        }
    }
}

//refresh page every 5 minutes
setTimeout(function () {
    window.location.reload(1);
}, 1000 * 5 * 60);

function doRequest() {

    // Creating Our XMLHttpRequest object 
    var xhr = new XMLHttpRequest();

    // Making our connection  
    var url = 'http://localhost:5000';
    xhr.open("GET", url, true);

    // function execute after request is successful 
    xhr.onreadystatechange = function () {
        if (this.readyState == 4 && this.status == 200) {

            let resp = JSON.parse(this.responseText);
            let recs = resp.status;
            let pipeline = resp.pipeline;

            var pipelineTable =
                `
                <div id="statusReport">
                    <img class="img" src='report/Kontur_logo_main.png' />
                    <div class="vertical-center">
                        <p>PIPELINE DASHBOARD</p>
                    </div>
                </div>
                <h2>Pipeline Status</h2>
                <table id="firstTable">
                    <tr>
                        <td><b>Present Status</b></td>
                        <td align="center"><b>` + pipeline.presentStatus + `</b></td>
                    </tr>
                    <tr>
                        <td>Targets total</td>
                        <td align="center">` + pipeline.nEvents + `</td>
                    </tr>
                    <tr>
                        <td>Targets in progress</td>
                        <td align="center">` + pipeline.nProgress + `</td>
                    </tr>
                    <tr>
                        <td>Targets frozen</td>
                        <td align="center">0</td>
                    </tr>
                    <tr>
                        <td>Targets failed</td>
                        <td align="center">` + pipeline.nFail + `</td>
                    </tr>
                    <tr>
                        <td>Oldest completed target</td>
                        <td align="center">` + formatDate(pipeline.oldestCompleteTime) + `</td>
                    </tr>
                </table>
                <h2>Target status</h2><a id="statusChart" target="_blank" href="make.svg">Status Chart</a></br> <input type="text"
                                id="myInput" onkeyup="filterTarget()" placeholder="Search for target name.." title="Type in a name">`


            let statusTable = `
                    <table id='statusTable' class='sortable'>
                        <tr class="header">
                            <th>Target name</th>
                            <th>Last completed date</th>
                            <th>Status</th>
                            <th>Status date</th>
                            <th>Duration</th>
                            <th>Log</th>
                        </tr>`

            for (var i = 0; i < recs.length; i++) {
                statusTable += "<tr class=" + recs[i].eventType + ">";
                statusTable += "<td>" + recs[i].eventN + "</td>";
                statusTable += "<td>" + formatDate(recs[i].lastEventTime) + "</td>";
                statusTable += "<td>" + recs[i].eventType + "</td>";
                statusTable += "<td>" + formatDate(recs[i].eventTime) + "</td>";
                statusTable += "<td>" + getTime(recs[i].eventDuration) + "</td>";
                statusTable += "<td><a target='_blank' href=logs/" + recs[i].log + "/" + recs[i].eventN + "/log.txt>...</a></td>";

            }

            statusTable += "</table></table>";

            appendHtml(document.body, pipelineTable + statusTable);
        }
    }
    // Sending request 
    xhr.send();
}

function appendHtml(el, str) {
    var div = document.createElement('div');
    div.innerHTML = str;
    while (div.children.length > 0) {
        el.appendChild(div.children[0]);
    }
}

function formatDate(date) {
    date = new Date(date);
    var aaaa = date.getUTCFullYear();
    var gg = date.getUTCDate();
    var mm = (date.getUTCMonth() + 1);

    if (gg < 10)
        gg = "0" + gg;

    if (mm < 10)
        mm = "0" + mm;

    var cur_day = aaaa + "-" + mm + "-" + gg;

    var hours = date.getUTCHours()
    var minutes = date.getUTCMinutes()
    var seconds = date.getUTCSeconds();

    if (hours < 10)
        hours = "0" + hours;

    if (minutes < 10)
        minutes = "0" + minutes;

    if (seconds < 10)
        seconds = "0" + seconds;

    return cur_day + " " + hours + ":" + minutes + ":" + seconds;

}

const getTime = (time) => {
    seconds = Math.floor(time);
    minutes = Math.floor(seconds / 60);
    hours = Math.floor(minutes / 60);
    days = Math.floor(hours / 24);
    hours = hours - (days * 24);
    minutes = minutes - (days * 24 * 60) - (hours * 60);
    seconds = seconds - (days * 24 * 60 * 60) - (hours * 60 * 60) - (minutes * 60);

    if (hours < 10)
        hours = "0" + hours;

    if (minutes < 10)
        minutes = "0" + minutes;

    if (seconds < 10)
        seconds = "0" + seconds;

    return hours + ":" + minutes + ":" + seconds
}

doRequest();