function filterTarget() {
    var input, filter, table, tr, td, i, txtValue;
    input = document.getElementById("myInput");

    filter = input.value.toUpperCase().split(" ").join("_");
    table = document.getElementById("myTable");
    tr = table.getElementsByTagName("tr");

    if (filter.startsWith('"') && filter.endsWith('"')) {
        filter = filter.substring(1);
        filter = filter.substring(0, filter.length - 1)
        for (i = 0; i < tr.length; i++) {
            td = tr[i].getElementsByTagName("td")[0];
            if (td) {
                txtValue = td.textContent || td.innerText;
                if (txtValue.toUpperCase() === filter ) {
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

setTimeout(function () {
    window.location.reload(1);
}, 1000 * 5 * 60);