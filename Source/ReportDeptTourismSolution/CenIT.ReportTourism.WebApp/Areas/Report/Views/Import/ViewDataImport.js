var _ViewDataImportActionURLs = {
    DataImport_GetViewDataImport: "/Report/Import/GetDataImport"
};
var _tableViewDataImport;
$(document).ready(function() {
    initTableViewDataImport();
});
//var arrCodeCurrency = ["2", "3", "4", "5", "10", "11", "12", "13", "17", "18", "19", "20"];
var arrCodeCurrency =
{
    "1": ["10", "11", "12", "13"], // Lĩnh vực Lưu trú
    "2": ["17", "18", "19", "20"], // Lĩnh vực Lữ hành
    "3": ["2", "3", "4", "5"] // Lĩnh vực Khu/điểm du lịch
};

function initTableViewDataImport() {
    _tableViewDataImport = $("#ViewDataImports").DataTable({
        "Responsive": true,
        "language": {
            "processing":
                "<div class='overlay custom-loader-background'><i class='fa fa-cog fa-spin custom-loader-color'></i></div>"
        },
        "lengthChange": false,
        "processing": true,
        "serverSide": true,
        "pageLength": 50,
        "info": false,
        "searching": false,
        "paging": false,
        "ajax": {
            "url": _ViewDataImportActionURLs.DataImport_GetViewDataImport,
            "type": "POST",
            "dataType": "JSON",
            "data": {
                "EnterpriseId": function() { return enterpriseId; },
                "ForMonth": function() { return forMonth; },
                "TypeReport": function() { return typeReport; }
            }
        },
        "columnDefs": [
            { "width": "120px", "targets": 0 },
            { "width": "10px", "targets": [1, 2] },
            { "width": "80px", "targets": [3, 4, 5] }
        ],
        "createdRow": function(row, data, dataIndex) {
            var summaryTargets = ["Tổng doanh thu", "Nộp ngân sách", "Kim ngạch xuất khẩu", "Kim ngạch nhập khẩu"];
            if ($.inArray(data.Targets, summaryTargets) !== -1) {
                $(row).addClass("business-product-summary");
            }
            if ((data.Unit == null || typeof data.Unit == "undefined" || data.Unit.length == 0) &&
                (data.Code == null || typeof data.Code == "undefined" || data.Code.length == 0)) {
                    $(row).addClass("business-product-category");
                    // Add COLSPAN attribute
                    $("td:eq(0)", row).attr("colspan", 6);

                    // Hide required number of columns
                    // next to the cell with COLSPAN attribute
                    $("td:eq(5)", row).remove();
                    $("td:eq(4)", row).remove();
                    $("td:eq(3)", row).remove();
                    $("td:eq(2)", row).remove();
                    $("td:eq(1)", row).remove();
                    //$('td:eq(3)', row).css('display', 'none');
            }
        },
        "columns": [
            //{
            //    "data": "",
            //    "defaultContent": "1",
            //    "render": function (data, type, row, meta) {
            //        return meta.row + 1;
            //    }
            //},
            {
                "data": "Targets",
                "defaultContent": ""
            },
            {
                "data": "Unit",
                "class": "text-center",
                "defaultContent": ""
            },
            {
                "data": "Code",
                "class": "text-center",
                "defaultContent": "",
                "render": function(data, type, row, meta) {
                    if (data == null || data.length === 0) return "";
                    if (data.indexOf("TM_") === 0) return "";
                    return data.padStart(2, "0");
                }
            },
            {
                "data": "AccumulatedBeginingOfYear",
                "class": "text-right",
                "defaultContent": "",
                "render": function(data, type, row, meta) {
                    if (type === "display" && data != null) {
                        var html = "";
                        //if ($.inArray(row.Code, arrCodeCurrency) !== -1) {
                        //    html = data.toLocaleString("he-IL", { style: "currency", currency: "VND" });
                        //} else {
                        //    html = data.toLocaleString("he-IL");
                        //}
                        html = Number(data).toLocaleString("vi-VN");
                        return html;
                    } else if (type === "sort") {
                        return data;
                    }
                    return data;
                }
            },
            {
                "data": "PerformPreviousPeriod",
                "class": "text-right",
                "defaultContent": "",
                "render": function(data, type, row, meta) {
                    if (type === "display" && data != null) {
                        var html = "";
                        //if ($.inArray(row.Code, arrCodeCurrency[row.TypeReport]) !== -1) {
                        //    html = data.toLocaleString("he-IL", { style: "currency", currency: "VND" });
                        //} else {
                        //    html = data.toLocaleString("he-IL");
                        //}
                        html = Number(data).toLocaleString("vi-VN");
                        return html;
                    } else if (type === "sort") {
                        return data;
                    }
                    return data;
                }
            },
            //{
            //    "data": "AccumulatedBeginingOfYear",
            //    "class": "text-right",
            //    "defaultContent": "",
            //    "render": function (data, type, row, meta) {
            //        if (type === "display" && data != null) {
            //            var html = "";
            //            //if ($.inArray(row.Code, arrCodeCurrency) !== -1) {
            //            //    html = data.toLocaleString("he-IL", { style: "currency", currency: "VND" });
            //            //} else {
            //            //    html = data.toLocaleString("he-IL");
            //            //}
            //            html = data.toLocaleString("he-IL");
            //            return html;
            //        } else if (type === "sort") {
            //            return data;
            //        }
            //        return data;
            //    }
            //},
            {
                "data": "PerformInPeriod",
                "class": "text-right",
                "defaultContent": "",
                "render": function(data, type, row, meta) {
                    if (type === "display" && data != null) {
                        var html = "";
                        //if ($.inArray(row.Code, arrCodeCurrency[row.TypeReport]) !== -1) {
                        //    html = data.toLocaleString("he-IL", { style: "currency", currency: "VND" });
                        //} else {
                        //    html = data.toLocaleString("he-IL");
                        //}
                        html = Number(data).toLocaleString("vi-VN");
                        return html;
                    } else if (type === "sort") {
                        return data;
                    }
                    return data;
                }
            }
        ]
    });
}
