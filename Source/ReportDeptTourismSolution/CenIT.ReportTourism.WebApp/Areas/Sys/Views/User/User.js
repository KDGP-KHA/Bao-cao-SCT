var _UserActionURLs = {
    User_GetData: "/Sys/User/Get"
};
var _tableUser;

$(document).ready(function() {
    initTableUser();

    $('.dataTables_filter input')
        .unbind('keypress keyup input')
        .bind('keypress', function (e) {
            // Check if the pressed key is Enter (keycode 13)
            if (e.which == 13) {
                _tableUser.search(this.value).draw();
            }
        });
});

function initTableUser() {
    _tableUser = $("#DSUser").DataTable({
        "Responsive": true,
        "language": {
            "processing":
                "<div class='overlay custom-loader-background'><i class='fa fa-cog fa-spin custom-loader-color'></i></div>"
        },
        "lengthChange": true,
        "processing": true,
        "serverSide": true,
        "search": {
            return: true
        },
        "ajax":
        {
            "url": _UserActionURLs.User_GetData,
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
                "data": "FullName",
                "defaultContent": ""
            },
            {
                "data": "UserName",
                "defaultContent": ""
            },
            {
                "data": "UserId",
                "style": "width:100px;",
                "orderable": false,
                "render": function(data, type, row, meta) {
                    var html = "";
                    if (type === "display") {
                        if (row.IsActive) {
                            html += _renderButton(true,
                                "ResetPassword",
                                "fa fa-key btn btn-default btn-form",
                                "/Sys/User/ResetPassword/" + data,
                                "",
                                "Đổi mật khẩu");

                            html += _renderButton(true,
                                "EditUser",
                                "fa fa-pencil btn btn-default btn-form",
                                "/Sys/User/Edit/" + data,
                                "",
                                "Cập nhật");
                            html += _renderButton(true,
                                "DeActiveUser",
                                "fa fa-ban btn btn-danger btn-form",
                                "/Sys/User/DeActive/" + data,
                                "",
                                "Ngưng hoạt động");

                            html += _renderButton(true,
                                "ConfirmSendMail",
                                "fa fa-envelope-o btn btn-sm bg-navy btn-form",
                                "/Sys/User/SendMail/" + data,
                                "",
                                "Reset mật khẩu");
                            if (row.CanEditIndustryPermissions === true) {
                                var industryTitle = $("#DSUser").attr("data-industry-permissions-title") || "";
                                // The shared renderer places titles inside an HTML attribute.
                                industryTitle = industryTitle.replace(/&/g, "&amp;").replace(/"/g, "&quot;")
                                    .replace(/</g, "&lt;").replace(/>/g, "&gt;");
                                html += _renderButton(true, "IndustryPermissions",
                                    "fa fa-industry btn btn-default btn-form",
                                    "/Sys/User/IndustryPermissions/" + data, "", industryTitle);
                            }

                            html += _renderButton(true,
                                "EnterprisesUser",
                                "fa fa-object-group btn btn-sm bg-purple btn-form",
                                "/Sys/User/EnterprisesUser/" + data,
                                "",
                                "Phân quyền doanh nghiệp");
                        } else {

                            html += _renderButton(true,
                                "ActiveUser",
                                "fa fa-check-square-o btn btn-primary btn-form",
                                "/Sys/User/Active/" + data,
                                "",
                                "Kích hoạt");

                        }
                    }

                    return html;
                }
            }
        ]
    }).on("xhr.dt",
        function(e, settings, json, xhr) {
            var a = 1;
        });
}

function User_OnProcessSuccess(response, formId) {
    if (response.status != undefined) {
        $("#ModalContent #modal_" + formId).modal("hide");
        $("#ModalContent #modal_" + formId).on("hidden.bs.modal",
            function() {
                if (response.status != undefined) {
                    eval(response.message);
                    _tableUser.ajax.reload(null, true);
                    response.status = undefined;
                }
            });
    } else if ($(response).hasClass("modal-header")) {
        $("#ModalContent #modal_" + formId + " #modal-content").html(response);
    } else {
        $("#ModalContent #modal_" + formId + " #bodyForm").html(response);
    }
}
