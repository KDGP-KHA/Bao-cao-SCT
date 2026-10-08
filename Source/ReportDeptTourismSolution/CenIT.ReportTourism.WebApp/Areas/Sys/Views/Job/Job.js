
var _JobActionURLs = {
    Job_GetData: "/Sys/Job/Get"
};
var _tableJob;

$(document).ready(function() {
    initTableJob();
});

function initTableJob() {
    _tableJob = $("#DSJob").DataTable({
        "Responsive": true,
        "language": {
            "processing":
                "<div class='overlay custom-loader-background'><i class='fa fa-cog fa-spin custom-loader-color'></i></div>"
        },
        "columnDefs": [
            { targets: [0, 1, 4, 5, 6], visible: true },
            { targets: "_all", visible: false }
        ],
        "lengthChange": true,
        "processing": true,
        "serverSide": true,
        "ajax":
        {
            "url": _JobActionURLs.Job_GetData,
            "type": "POST",
            "dataType": "JSON"
        },
        "columns": [
            {
                "data": "",
                "defaultContent": "1",
                "render": function(data, type, row, meta) {
                    return meta.row + 1;
                }
            },
            {
                "data": "JobName",
                "defaultContent": ""
            },
            {
                "data": "JobDescription",
                "defaultContent": ""
            },
            {
                "data": "CronExpression",
                "defaultContent": ""
            },
            {
                "data": "JobLibrary",
                "defaultContent": ""
            },
            {
                "data": "IsActive",
                "class": "text-center",
                "defaultContent": "",
                "render": function(data, type, row, meta) {
                    var html = '<h4><span class="label label-danger">Tạm dừng</span></h4>';
                    if (data) {
                        //html = '<i class="fa fa-check text-green"></i>'
                        html = '<h4><span class="label label-success">Hoạt động</span></h4>';
                    }
                    return html;
                }
            },
            {
                "data": "JobId",
                "style": "width:100px;",
                "orderable": false,
                "render": function(data, type, row, meta) {
                    var html = "";
                    if (type === "display") {
                        var text = row.IsActive ? "Ngưng hoạt động" : "Kích hoạt lại";
                        var classButton = row.IsActive ? "fa fa-ban btn btn-warning" : "fa fa-check btn btn-success";

                        html += _renderButton(true,
                            "ChangeStatusJob",
                            classButton + " btn-form",
                            "/Sys/Job/ChangeStatus/" + data,
                            "",
                            text);

                        html += _renderButton(true,
                            "EditJob",
                            "fa fa-pencil btn btn-default btn-form",
                            "/Sys/Job/Edit/" + data,
                            "",
                            "Cập nhật",
                            860);

                        html += _renderButton(true,
                            "DeleteJob",
                            "fa fa-trash-o btn btn-danger btn-form",
                            "/Sys/Job/Delete/" + data,
                            "",
                            "Xoá");
                    }

                    return html;
                }
            }
        ]
    });
}

function Job_OnProcessSuccess(response, formId) {
    if (response.status != undefined) {
        $("#ModalContent #modal_" + formId).modal("hide");
        $("#ModalContent #modal_" + formId).on("hidden.bs.modal",
            function() {
                if (response.status != undefined) {
                    eval(response.message);
                    _tableJob.ajax.reload(null, true);
                    response.status = undefined;
                }
            });
    } else {
        $("#ModalContent #modal_" + formId + " #bodyForm").html(response);
    }
}