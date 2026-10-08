var _EconomicSectorActionURLs = {
    EconomicSector_GetData: "/Cate/EconomicSector/Get"
};
var _tableNatinal;
$(document).ready(function() {
    initTableEconomicSector();
});

function initTableEconomicSector() {
    _tableNatinal = $("#DSEconomicSector").DataTable({
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
            "url": _EconomicSectorActionURLs.EconomicSector_GetData,
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
                "data": "EconomicSectorId",
                "style": "width:100px;",
                "orderable": false,
                "render": function(data, type, row, meta) {
                    var html = "";
                    if (type === "display") {

                        html += _renderButton(true,
                            "EditEconomicSector",
                            "fa fa-pencil btn btn-default btn-form",
                            "/Cate/EconomicSector/Edit/" + data,
                            "",
                            "Cập nhật");

                        html += _renderButton(true,
                            "DeleteEconomicSector",
                            "fa fa-trash-o btn btn-danger btn-form",
                            "/Cate/EconomicSector/Delete/" + data,
                            "",
                            "Xoá");
                    }

                    return html;
                }
            }
        ]
    });
}

function AppEconomicSector_OnProcessSuccess(response, formId) {
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