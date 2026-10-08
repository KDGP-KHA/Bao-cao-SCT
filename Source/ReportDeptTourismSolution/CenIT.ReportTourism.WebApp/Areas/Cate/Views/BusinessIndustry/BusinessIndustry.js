var _BusinessIndustryActionURLs = {
    BusinessIndustry_GetData: "/Cate/BusinessIndustry/Get"
};
var _tableNatinal;
$(document).ready(function() {
    initTableBusinessIndustry();
});

function initTableBusinessIndustry() {
    _tableNatinal = $("#DSBusinessIndustry").DataTable({
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
            "url": _BusinessIndustryActionURLs.BusinessIndustry_GetData,
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
                "data": "IndustryCode",
                "defaultContent": ""
            },
            {
                "data": "IndustryName",
                "defaultContent": ""
            },
            {
                "data": "IndustryId",
                "style": "width:100px;",
                "orderable": false,
                "render": function(data, type, row, meta) {
                    var html = "";
                    if (type === "display") {

                        html += _renderButton(true,
                            "ListBusinessProduct",
                            "fa fa-list btn bg-navy btn-form",
                            "/Cate/BusinessIndustry/Products/" + data,
                            "",
                            "Danh sách sản phẩm", 860);

                        html += _renderButton(true,
                            "EditBusinessIndustry",
                            "fa fa-pencil btn btn-default btn-form",
                            "/Cate/BusinessIndustry/Edit/" + data,
                            "",
                            "Cập nhật");

                        html += _renderButton(true,
                            "DeleteBusinessIndustry",
                            "fa fa-trash-o btn btn-danger btn-form",
                            "/Cate/BusinessIndustry/Delete/" + data,
                            "",
                            "Xoá");
                    }

                    return html;
                }
            }
        ]
    });
}

function AppBusinessIndustry_OnProcessSuccess(response, formId) {
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