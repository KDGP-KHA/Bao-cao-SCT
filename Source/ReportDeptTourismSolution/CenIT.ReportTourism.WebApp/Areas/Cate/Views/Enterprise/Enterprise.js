var _EnterpriseActionURLs = {
    Enterprise_GetData: "/Cate/Enterprise/Get",
    Enterprise_MainProductViaIndustries: "/Cate/Enterprise/MainProductViaIndustries"
};
var _tableEnterprise;
$(document).ready(function () {
    initTableEnterprise();
});

function initTableEnterprise() {
    _tableEnterprise = $("#DSEnterprise").DataTable({
        "Responsive": true,
        "language": {
            "processing":
                "<div class='overlay custom-loader-background'><i class='fa fa-cog fa-spin custom-loader-color'></i></div>"
        },
        "columnDefs": [
            { targets: [0, 1, 2, -1], visible: true },
            { targets: "_all", visible: false }
        ],
        "lengthChange": true,
        "processing": true,
        "serverSide": true,
        "ajax":
        {
            "url": _EnterpriseActionURLs.Enterprise_GetData,
            "type": "POST",
            "dataType": "JSON",
            "data": {
                "WardIds": function () {
                    return $("#Search select#ListWardId").val() != null &&
                        $("#Search select#ListWardId").val().length > 0
                        ? $("#Search select#ListWardId").val()
                        : "";
                },
                "TypeBusinessIds": function () {
                    return $("#Search select#ListTypeBusinessId").val() != null &&
                        $("#Search select#ListTypeBusinessId").val().length > 0
                        ? $("#Search select#ListTypeBusinessId").val()
                        : "";
                },
                "MainIndustryIds": function () {
                    return $("#Search select#ListMainIndustryId").val() != null &&
                        $("#Search select#ListMainIndustryId").val().length > 0
                        ? $("#Search select#ListMainIndustryId").val()
                        : "";
                },
                "EnterpriseTypeIds": function () {
                    return $("#Search select#ListEnterpriseTypeId").val() != null &&
                        $("#Search select#ListEnterpriseTypeId").val().length > 0
                        ? $("#Search select#ListEnterpriseTypeId").val()
                        : "";
                },
                "EconomicSectorIds": function () {
                    return $("#Search select#ListEconomicSectorId").val() != null &&
                        $("#Search select#ListEconomicSectorId").val().length > 0
                        ? $("#Search select#ListEconomicSectorId").val()
                        : "";
                },
                "StatusIds": function () {
                    return $("#Search select#ListStatusId").val() != null &&
                        $("#Search select#ListStatusId").val().length > 0
                        ? $("#Search select#ListStatusId").val()
                        : "";
                },
            }
        },
        "columns": [
            {
                "data": "",
                "defaultContent": "1",
                "render": function (data, type, row, meta) {
                    return meta.row + 1;
                }
            },
            {
                "data": "OwnerEnterpriseName",
                "defaultContent": ""
            },
            {
                "data": "BusinessName",
                "defaultContent": ""
            },
            {
                "data": "TaxCode",
                "defaultContent": ""
            },
            {
                "data": "WardName",
                "defaultContent": ""
            },
            {
                "data": "ProvinceName",
                "defaultContent": ""
            },
            {
                "data": "EnterpriseTypeName",
                "defaultContent": ""
            },
            {
                "data": "EconomicSectorName",
                "defaultContent": ""
            },
            {
                "data": "EnterpriseStatusName",
                "defaultContent": ""
            },
            {
                "data": "EnterpriseId",
                "style": "width:100px;",
                "orderable": false,
                "render": function (data, type, row, meta) {
                    var html = "";
                    if (type === "display") {
                        if (row.IsActive) {
                            html += _renderButton(true,
                                "EditEnterprise",
                                "fa fa-pencil btn btn-default btn-form",
                                "/Cate/Enterprise/Edit/" + data,
                                "",
                                "Cập nhật",
                                1024);
                            html += _renderButton(true,
                                "ChangeStatusEnterprise",
                                "fa fa-lock btn bg-gray btn-form",
                                "/Cate/Enterprise/ChangeStatus/" + data,
                                "",
                                "Ngưng hoạt động Doanh nghiệp");
                        } else {
                            html += _renderButton(true,
                                "ChangeStatusEnterprise",
                                "fa fa-unlock btn bg-primary btn-form",
                                "/Cate/Enterprise/ChangeStatus/" + data,
                                "",
                                "Kích hoạt lại Doanh nghiệp");
                        }

                        html += _renderButton(true,
                            "DeleteEnterprise",
                            "fa fa-trash-o btn btn-danger btn-form",
                            "/Cate/Enterprise/Delete/" + data,
                            "",
                            "Xoá");
                    }
                    return html;
                }
            }
        ]
    });
}

function Enterprise_OnProcessSuccess(response, formId) {
    if (response.status != undefined) {
        $("#ModalContent #modal_" + formId).modal("hide");
        $("#ModalContent #modal_" + formId).on("hidden.bs.modal",
            function () {
                if (response.status != undefined) {
                    eval(response.message);
                    _tableEnterprise.ajax.reload(null, false);
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

function CateDoc_OnProcessSuccess(response, formId) {
    if (response.status != undefined) {
        $("#ModalContent #modal_" + formId).modal("hide");
        $("#ModalContent #modal_" + formId).on("hidden.bs.modal",
            function () {
                if (response.status != undefined) {
                    eval(response.message);
                    //_tableUnionResolution.ajax.reload(null, false);
                    var fileId = response.fileId;
                    $('li[id="' + fileId + '"]').remove();
                    response.status = undefined;
                }
            });
    } else {
        $("#ModalContent #modal_" + formId + " #bodyForm").html(response);
    }
}

function OnChangeProvince(cbbProvince, cbbWard) {
    if ($("#ProvinceName").length > 0) {
        $("#ProvinceName").val($(cbbProvince).children("option:selected").text());
    }
    var wardId = $(cbbWard).val();

    $(cbbWard).empty();
    $(cbbWard).trigger("chosen:updated");
    var selected = $(cbbProvince).val();
    var url = "/Cate/Enterprise/WardViaProvince?provinceId=" + selected;
    $.ajax({
        type: "GET",
        url: url,
        dataType: "JSON",
        success: function (response) {
            $(cbbWard).append('<option value=""></option>');
            $.each(response.Wards,
                function (index, item) {
                    var selected = "";
                    if (wardId.length > 0 && wardId != "0") {
                        if (item.WardId == wardId)
                            selected = "selected";
                    }
                    $(cbbWard).append('<option value="' +
                        item.WardId +
                        '" ' +
                        selected +
                        ">" +
                        item.WardName +
                        "</option>");
                });
        }
    });
}

// Nạp lại dropdown "Sản phẩm chính" theo các ngành công nghiệp đang chọn
function OnChangeIndustries(cbbIndustry, cbbProduct) {
    var industryIds = $.grep($(cbbIndustry).val() || [], function (id) { return id; }).join(",");

    // Đổi ngành liên tục: bỏ request cũ, chỉ lấy kết quả của lần chọn cuối
    var request = $(cbbProduct).data("request");
    if (request) request.abort();

    if (industryIds.length === 0) {
        FillMainProducts(cbbProduct, []);
        return;
    }

    request = $.ajax({
        type: "GET",
        url: _EnterpriseActionURLs.Enterprise_MainProductViaIndustries,
        data: { industryIds: industryIds },
        dataType: "JSON",
        success: function (response) {
            FillMainProducts(cbbProduct, response.Products);
        },
        complete: function () {
            if ($(cbbProduct).data("request") === request) $(cbbProduct).removeData("request");
        }
    });
    $(cbbProduct).data("request", request);
}

// Giữ lại sản phẩm đang chọn nếu vẫn thuộc danh sách mới, ngược lại bỏ chọn
function FillMainProducts(cbbProduct, products) {
    var productId = $(cbbProduct).val();

    $(cbbProduct).empty().append('<option value=""></option>');
    $.each(products || [],
        function (index, item) {
            $(cbbProduct).append($("<option></option>").val(item.Value).text(item.Text));
        });

    var hasProduct = !!productId && $(cbbProduct).find("option").filter(function () {
        return this.value === productId;
    }).length > 0;
    $(cbbProduct).val(hasProduct ? productId : "").trigger("change");
}
