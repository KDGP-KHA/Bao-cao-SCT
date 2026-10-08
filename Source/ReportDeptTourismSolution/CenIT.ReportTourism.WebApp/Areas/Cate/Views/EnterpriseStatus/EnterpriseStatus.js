var _EnterpriseStatusActionURLs = {
    EnterpriseStatus_GetData: "/Cate/EnterpriseStatus/Get"
};
var _tableNatinal;
$(document).ready(function() {
    initTableEnterpriseStatus();
});

function initTableEnterpriseStatus() {
    _tableNatinal = $("#DSEnterpriseStatus").DataTable({
        "Responsive": true,
        "language": {
            "processing":
                "<div class='overlay custom-loader-background'><i class='fa fa-cog fa-spin custom-loader-color'></i></div>"
        },
        "lengthChange": true,
        "processing": true,
        "serverSide": true,
        "ajax":
        {
            "url": _EnterpriseStatusActionURLs.EnterpriseStatus_GetData,
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
                "data": "Code",
                "defaultContent": ""
            },
            {
                "data": "Name",
                "defaultContent": ""
            },
            {
                "data": "EnterpriseStatusId",
                "style": "width:100px;",
                "orderable": false,
                "render": function(data, type, row, meta) {
                    var html = "";
                    if (type === "display") {

                        html += _renderButton(true,
                            "EditEnterpriseStatus",
                            "fa fa-pencil btn btn-default btn-form",
                            "/Cate/EnterpriseStatus/Edit/" + data,
                            "",
                            "Cập nhật");

                        html += _renderButton(true,
                            "DeleteEnterpriseStatus",
                            "fa fa-trash-o btn btn-danger btn-form",
                            "/Cate/EnterpriseStatus/Delete/" + data,
                            "",
                            "Xoá");
                    }

                    return html;
                }
            }
        ]
    });
}

function AppEnterpriseStatus_OnProcessSuccess(response, formId) {
    if (response.status != undefined) {
        $("#ModalContent #modal_" + formId).modal("hide");
        $("#ModalContent #modal_" + formId).on("hidden.bs.modal",
            function() {
                if (response.status != undefined) {
                    eval(response.message);
                    _tableNatinal.ajax.reload(null, false);
                    response.status = undefined;
                }
            });
    } else {
        $("#ModalContent #modal_" + formId + " #bodyForm").html(response);
    }
}

function OnChangeCombo(cbb, eleName) {
    $(eleName).val($(cbb).children("option:selected").text());
}